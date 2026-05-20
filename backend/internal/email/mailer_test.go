package email

import (
	"context"
	"strings"
	"testing"
)

// LogMailer never errors, even on extremely long bodies.
func TestLogMailerSendDoesNotError(t *testing.T) {
	m := LogMailer{Log: nil}
	if err := m.Send(context.Background(), "u@example.com", "subj",
		"<p>html</p>", strings.Repeat("x", 5000)); err != nil {
		t.Fatalf("Send: %v", err)
	}
}

// Render produces three non-empty strings for each supported locale.
func TestRenderAllLocales(t *testing.T) {
	data := TemplateData{
		DisplayName:  "Akira",
		VerifyLink:   "https://example.com/verify?token=abc",
		AppName:      "KAMOS",
		SupportEmail: "support@kamos.app",
	}
	wantSubjects := map[string]string{
		"en": "Verify your KAMOS email",
		"ja": "KAMOSメールアドレスの確認",
		"ko": "KAMOS 이메일 인증",
	}
	for locale, wantSubject := range wantSubjects {
		t.Run(locale, func(t *testing.T) {
			subject, html, text, err := Render("verify_email", locale, data)
			if err != nil {
				t.Fatalf("Render: %v", err)
			}
			if subject != wantSubject {
				t.Errorf("subject: got %q want %q", subject, wantSubject)
			}
			if !strings.Contains(html, data.VerifyLink) {
				t.Errorf("html missing verify link")
			}
			if !strings.Contains(text, data.VerifyLink) {
				t.Errorf("text missing verify link")
			}
			if !strings.Contains(html, data.DisplayName) {
				t.Errorf("html missing display name")
			}
		})
	}
}

// Unknown locale falls back to English (matches SPEC §6.5 i18n fallback).
func TestRenderUnknownLocaleFallsBackToEN(t *testing.T) {
	data := TemplateData{
		DisplayName: "Yuki", VerifyLink: "https://example.com/v",
		AppName: "KAMOS", SupportEmail: "support@kamos.app",
	}
	subject, html, _, err := Render("verify_email", "fr", data)
	if err != nil {
		t.Fatalf("Render: %v", err)
	}
	if subject != "Verify your KAMOS email" {
		t.Errorf("subject (fallback): %q", subject)
	}
	if !strings.Contains(html, "Welcome to KAMOS") {
		t.Errorf("html not English: %q", html[:min(120, len(html))])
	}
}

// Unknown template name errors out.
func TestRenderUnknownTemplate(t *testing.T) {
	if _, _, _, err := Render("does_not_exist", "en", TemplateData{}); err == nil {
		t.Fatal("expected error for unknown template")
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
