package email

import (
	"context"
	"log/slog"
)

// LogMailer is the default when RESEND_API_KEY is empty. It logs the
// outbound mail at INFO so dev can copy/paste verification links from the
// API stdout. Never errors.
type LogMailer struct {
	Log *slog.Logger
}

func (m LogMailer) Send(ctx context.Context, to, subject, htmlBody, textBody string) error {
	preview := textBody
	if len(preview) > 200 {
		preview = preview[:200]
	}
	if m.Log != nil {
		m.Log.Info("mail_logged",
			"to", to,
			"subject", subject,
			"text_preview", preview,
		)
	}
	return nil
}
