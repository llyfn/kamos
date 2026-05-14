package email

import (
	"log/slog"

	"github.com/kamos/api/internal/config"
)

// NewMailer chooses the backend based on cfg. Both keys required for Resend;
// missing either falls back to the log-only mailer so dev workflow stays
// intact and the API process never refuses to boot.
func NewMailer(cfg *config.Config, log *slog.Logger) Mailer {
	if cfg != nil && cfg.ResendAPIKey != "" && cfg.EmailFrom != "" {
		return NewResendMailer(cfg.ResendAPIKey, cfg.EmailFrom, log)
	}
	return LogMailer{Log: log}
}
