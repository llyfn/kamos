// Package email is the outbound-mail façade. Two implementations:
//   - LogMailer: writes the subject + first line of textBody to slog (default
//     when RESEND_API_KEY is empty; keeps dev workflow intact).
//   - ResendMailer: POST to https://api.resend.com/emails via net/http.
//
// Templates live under templates/ and are embedded so the production binary
// is fully self-contained. Render picks the locale, falling back to "en".
package email

import "context"

// Mailer is the surface every handler depends on.
type Mailer interface {
	Send(ctx context.Context, to, subject, htmlBody, textBody string) error
}
