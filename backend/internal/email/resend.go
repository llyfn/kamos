package email

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"time"

	"github.com/getsentry/sentry-go"
)

// resendEndpoint is the only Resend route we use.
const resendEndpoint = "https://api.resend.com/emails"

// ResendMailer ships outbound mail through Resend's REST API.
//
// We intentionally avoid the `resend-go` SDK to keep the dependency
// surface minimal — the wire protocol is a single POST.
type ResendMailer struct {
	APIKey string
	From   string
	Log    *slog.Logger
	HTTP   *http.Client // nil → default with 10s timeout
}

// NewResendMailer builds the mailer with a sensible HTTP client.
func NewResendMailer(apiKey, from string, log *slog.Logger) *ResendMailer {
	return &ResendMailer{
		APIKey: apiKey,
		From:   from,
		Log:    log,
		HTTP:   &http.Client{Timeout: 10 * time.Second},
	}
}

type resendRequest struct {
	From    string   `json:"from"`
	To      []string `json:"to"`
	Subject string   `json:"subject"`
	HTML    string   `json:"html"`
	Text    string   `json:"text"`
}

// Send POSTs the message to Resend with one retry on 5xx.
//
// On persistent failure we forward the error to Sentry (if enabled) so SMTP
// failures show up in production observability instead of vanishing into the
// log stream.
func (m *ResendMailer) Send(ctx context.Context, to, subject, htmlBody, textBody string) error {
	body, err := json.Marshal(resendRequest{
		From:    m.From,
		To:      []string{to},
		Subject: subject,
		HTML:    htmlBody,
		Text:    textBody,
	})
	if err != nil {
		return fmt.Errorf("ResendMailer.Send: marshal: %w", err)
	}

	client := m.HTTP
	if client == nil {
		client = &http.Client{Timeout: 10 * time.Second}
	}

	var lastErr error
	for attempt := 0; attempt < 2; attempt++ {
		if attempt > 0 {
			time.Sleep(time.Second)
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, resendEndpoint, bytes.NewReader(body))
		if err != nil {
			return fmt.Errorf("ResendMailer.Send: build req: %w", err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+m.APIKey)

		resp, err := client.Do(req)
		if err != nil {
			lastErr = fmt.Errorf("ResendMailer.Send: do: %w", err)
			continue
		}
		respBody, _ := io.ReadAll(resp.Body)
		_ = resp.Body.Close()

		if resp.StatusCode >= 200 && resp.StatusCode < 300 {
			if m.Log != nil {
				m.Log.Info("mail_sent",
					"provider", "resend",
					"to", to,
					"subject", subject,
				)
			}
			return nil
		}
		// 5xx → retry once, 4xx → terminal.
		if resp.StatusCode >= 500 {
			lastErr = fmt.Errorf("ResendMailer.Send: status=%d body=%s", resp.StatusCode, string(respBody))
			continue
		}
		lastErr = fmt.Errorf("ResendMailer.Send: status=%d body=%s", resp.StatusCode, string(respBody))
		break
	}

	// Forward persistent failure to Sentry so we see SMTP issues in prod.
	sentry.CaptureException(lastErr)
	if m.Log != nil {
		m.Log.Warn("mail_send_failed",
			"provider", "resend",
			"to", to,
			"err", lastErr,
		)
	}
	return lastErr
}
