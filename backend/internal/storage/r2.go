// Package storage — Cloudflare R2 backend.
//
// R2 implements the S3 API. We use aws-sdk-go-v2 + a presign client; region
// is the constant "auto" per R2's documentation, and the BaseEndpoint option
// points the SDK at the R2 gateway URL (e.g. https://<account-id>.r2.cloudflarestorage.com).
//
// PublicURL is intentionally NOT the bucket URL — production serves photos
// through a CDN / custom domain configured separately (R2 dashboard
// "Custom Domains" or "Public Access" via `pub-<id>.r2.dev`). We store that
// base URL in R2_PUBLIC_BASE_URL and stitch it to the blob_key.
package storage

import (
	"context"
	"fmt"
	"net/url"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// R2 is the production Storage backend.
type R2 struct {
	bucket        string
	publicBaseURL string
	client        *s3.Client
	presigner     *s3.PresignClient
}

// NewR2 constructs the backend. Returns an error if `endpoint` is not a valid
// URL — bad config should fail fast, not silently.
func NewR2(ctx context.Context, endpoint, accessKey, secretKey, bucket, publicBaseURL string) (*R2, error) {
	if endpoint != "" {
		// Validate eagerly. aws-sdk-go-v2 itself would only complain at
		// request time which is far too late.
		if _, err := url.ParseRequestURI(endpoint); err != nil {
			return nil, fmt.Errorf("NewR2: bad R2_ENDPOINT_URL %q: %w", endpoint, err)
		}
	}
	cfg, err := config.LoadDefaultConfig(ctx,
		config.WithRegion("auto"),
		config.WithCredentialsProvider(
			credentials.NewStaticCredentialsProvider(accessKey, secretKey, ""),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("NewR2: load aws config: %w", err)
	}

	client := s3.NewFromConfig(cfg, func(o *s3.Options) {
		if endpoint != "" {
			o.BaseEndpoint = aws.String(endpoint)
		}
		// R2 needs path-style addressing.
		o.UsePathStyle = true
	})

	return &R2{
		bucket:        bucket,
		publicBaseURL: strings.TrimRight(publicBaseURL, "/"),
		client:        client,
		presigner:     s3.NewPresignClient(client),
	}, nil
}

// PresignPut issues a one-shot PUT URL valid for `ttl`.
func (r *R2) PresignPut(ctx context.Context, blobKey, contentType string, byteSize int64, ttl time.Duration) (*PresignedPut, error) {
	if ttl <= 0 {
		ttl = 15 * time.Minute
	}
	if ttl > time.Hour {
		ttl = time.Hour
	}

	in := &s3.PutObjectInput{
		Bucket:        aws.String(r.bucket),
		Key:           aws.String(blobKey),
		ContentType:   aws.String(contentType),
		ContentLength: aws.Int64(byteSize),
	}
	out, err := r.presigner.PresignPutObject(ctx, in, func(o *s3.PresignOptions) {
		o.Expires = ttl
	})
	if err != nil {
		return nil, fmt.Errorf("R2.PresignPut: %w", err)
	}

	// Headers the client MUST replay on the PUT. The Content-Type and
	// Content-Length are baked into the signature; deviating from them
	// will fail with SignatureDoesNotMatch on R2's side.
	headers := map[string]string{
		"Content-Type": contentType,
	}
	for k, vs := range out.SignedHeader {
		if len(vs) > 0 {
			headers[k] = vs[0]
		}
	}

	return &PresignedPut{
		URL:       out.URL,
		Headers:   headers,
		BlobKey:   blobKey,
		ExpiresAt: time.Now().Add(ttl),
	}, nil
}

// PublicURL returns the customer-facing URL for a blob.
func (r *R2) PublicURL(blobKey string) string {
	if r.publicBaseURL == "" {
		return ""
	}
	return r.publicBaseURL + "/" + strings.TrimLeft(blobKey, "/")
}

// Delete removes a blob. Used by the orphan-cleanup job. We swallow
// NoSuchKey because already-gone is the same as gone.
func (r *R2) Delete(ctx context.Context, blobKey string) error {
	_, err := r.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(r.bucket),
		Key:    aws.String(blobKey),
	})
	if err != nil {
		return fmt.Errorf("R2.Delete: %w", err)
	}
	return nil
}
