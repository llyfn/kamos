package email

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"sync"
	"time"

	"github.com/getsentry/sentry-go"
)

// resendEndpoint is the only Resend route we use.
const resendEndpoint = "https://api.resend.com/emails"

// resendQueueDepth is the size of the in-process outbound-mail queue.
// 100 slots — small enough that an outage doesn't pile up unbounded
// memory in the API process, large enough that bursty traffic (e.g.,
// a moderation re-verification storm) doesn't drop on the first
// post-restart spike.
const resendQueueDepth = 100

// resendWorkerCount is the number of goroutines draining the queue.
// Two workers strike the balance between throughput (Resend caps
// each connection at ~10 rps in practice) and the bookkeeping of
// long-lived goroutines. A future spike can raise the count.
const resendWorkerCount = 2

// ResendMailer ships outbound mail through Resend's REST API.
//
// Stage 5 (PERF-029): the previous shape blocked the caller for one
// in-request HTTP round trip plus, on 5xx, a `time.Sleep(1s)` retry.
// The Sleep tied up the request goroutine and the user-visible
// latency for /v1/auth/register included the Resend POST. We now
// enqueue the request onto a bounded channel and let two background
// workers drain it; Send returns nil after a successful enqueue,
// errors only on shutdown or a full queue.
//
// We intentionally avoid the resend-go SDK to keep the dependency
// surface minimal — the wire protocol is a single POST.
type ResendMailer struct {
	APIKey string
	From   string
	Log    *slog.Logger
	HTTP   *http.Client

	queue   chan resendRequest
	wg      sync.WaitGroup
	stopped chan struct{}
}

// NewResendMailer builds the mailer with a sensible HTTP client and
// starts the background worker pool. The workers exit when Stop is
// called; we don't currently wire Stop to a server-side shutdown
// hook — when we do (post-Stage 9 graceful drain), in-flight mail
// finishes; queued-but-not-sent mail is dropped with a log line.
func NewResendMailer(apiKey, from string, log *slog.Logger) *ResendMailer {
	m := &ResendMailer{
		APIKey:  apiKey,
		From:    from,
		Log:     log,
		HTTP:    &http.Client{Timeout: 10 * time.Second},
		queue:   make(chan resendRequest, resendQueueDepth),
		stopped: make(chan struct{}),
	}
	for i := 0; i < resendWorkerCount; i++ {
		m.wg.Add(1)
		go m.worker()
	}
	return m
}

type resendRequest struct {
	From    string   `json:"from"`
	To      []string `json:"to"`
	Subject string   `json:"subject"`
	HTML    string   `json:"html"`
	Text    string   `json:"text"`
}

// Send enqueues the message. Returns nil on successful enqueue; an
// error when the queue is full (caller may decide whether to surface
// to the user — we currently log + swallow at the call site so a
// transient outage doesn't fail registration).
//
// The provided ctx is not propagated into the actual HTTP send: the
// caller's request has already returned by the time the worker
// fires. A future improvement is to carry a request-id breadcrumb
// through so observability can stitch the two.
func (m *ResendMailer) Send(ctx context.Context, to, subject, htmlBody, textBody string) error {
	req := resendRequest{
		From:    m.From,
		To:      []string{to},
		Subject: subject,
		HTML:    htmlBody,
		Text:    textBody,
	}
	select {
	case m.queue <- req:
		return nil
	default:
		// Bounded queue overflow. Log + Sentry the drop so a sustained
		// outage is visible; do not block the request goroutine.
		err := fmt.Errorf("ResendMailer.Send: queue full (depth=%d) — dropping mail to %s", resendQueueDepth, to)
		sentry.CaptureException(err)
		if m.Log != nil {
			m.Log.Warn("mail_queue_full",
				"provider", "resend",
				"to", to,
				"subject", subject,
			)
		}
		return err
	}
}

// Stop signals the workers to drain and exit. Safe to call multiple
// times — successive calls observe the closed channel and return
// immediately. Not currently invoked by the API server's shutdown
// path; left in place for the eventual graceful-drain plumbing.
func (m *ResendMailer) Stop() {
	select {
	case <-m.stopped:
		return
	default:
		close(m.stopped)
	}
	close(m.queue)
	m.wg.Wait()
}

func (m *ResendMailer) worker() {
	defer m.wg.Done()
	for req := range m.queue {
		m.send(req)
	}
}

// send is the actual HTTP POST. Runs in the worker goroutine; failure
// is logged + reported to Sentry but never propagated back to the
// caller (Send has already returned).
func (m *ResendMailer) send(req resendRequest) {
	body, err := json.Marshal(req)
	if err != nil {
		m.reportFailure(req, fmt.Errorf("ResendMailer.send: marshal: %w", err))
		return
	}
	// Each send gets its own 10-second timeout context; the worker
	// goroutine has no inbound context to inherit.
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, resendEndpoint, bytes.NewReader(body))
	if err != nil {
		m.reportFailure(req, fmt.Errorf("ResendMailer.send: build req: %w", err))
		return
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+m.APIKey)

	client := m.HTTP
	if client == nil {
		client = &http.Client{Timeout: 10 * time.Second}
	}
	resp, err := client.Do(httpReq)
	if err != nil {
		m.reportFailure(req, fmt.Errorf("ResendMailer.send: do: %w", err))
		return
	}
	respBody, _ := io.ReadAll(resp.Body)
	_ = resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		if m.Log != nil {
			m.Log.Info("mail_sent",
				"provider", "resend",
				"to", req.To[0],
				"subject", req.Subject,
			)
		}
		return
	}
	m.reportFailure(req, fmt.Errorf("ResendMailer.send: status=%d body=%s", resp.StatusCode, string(respBody)))
}

func (m *ResendMailer) reportFailure(req resendRequest, err error) {
	sentry.CaptureException(err)
	if m.Log != nil {
		m.Log.Warn("mail_send_failed",
			"provider", "resend",
			"to", req.To[0],
			"err", err,
		)
	}
}
