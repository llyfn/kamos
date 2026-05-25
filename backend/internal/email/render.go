package email

import (
	"bytes"
	"embed"
	"fmt"
	htmltmpl "html/template"
	"strings"
	texttmpl "text/template"
)

//go:embed templates/*.tmpl
var templatesFS embed.FS

// TemplateData is the binding fed to every locale variant of a template.
type TemplateData struct {
	DisplayName  string
	VerifyLink   string
	AppName      string
	SupportEmail string
}

// Subject lines are hard-coded by locale; the body templates DO NOT carry
// a subject line. Keeping them apart avoids fragile "Subject: " parsing and
// keeps the human-readable templates pure.
var subjects = map[string]map[string]string{
	"verify_email": {
		"en": "Verify your KAMOS email",
		"ja": "KAMOSメールアドレスの確認",
		"ko": "KAMOS 이메일 인증",
	},
}

// supportedLocales is the list of locales we ship templates for. Anything
// else falls back to "en" (matches SPEC §6.5 i18n fallback rule).
var supportedLocales = map[string]bool{
	"en": true,
	"ja": true,
	"ko": true,
}

// LandingData is the binding fed to the verify_landing.* templates. Status
// is one of "Verified", "AlreadyVerified", "Invalid"; the template branches
// on it via {{if eq .Status "..."}}. AppName is always "KAMOS" today but is
// passed through so the templates stay parametric.
type LandingData struct {
	Status  string
	AppName string
}

// RenderLanding produces the HTML body for the post-click email-verification
// landing page in the requested locale. Unknown locales fall back to en.
// Returns an error only if the template file is missing or malformed.
func RenderLanding(locale, status string) (string, error) {
	if !supportedLocales[locale] {
		locale = "en"
	}
	path := fmt.Sprintf("templates/verify_landing.%s.html.tmpl", locale)
	raw, err := templatesFS.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("RenderLanding: read: %w", err)
	}
	t, err := htmltmpl.New(path).Parse(string(raw))
	if err != nil {
		return "", fmt.Errorf("RenderLanding: parse: %w", err)
	}
	var buf bytes.Buffer
	if err := t.Execute(&buf, LandingData{Status: status, AppName: "KAMOS"}); err != nil {
		return "", fmt.Errorf("RenderLanding: exec: %w", err)
	}
	return buf.String(), nil
}

// Render produces (subject, htmlBody, textBody) for the given template name
// and locale. Unknown locales fall back to en. Returns an error only if the
// template files are missing/malformed — never on locale.
func Render(templateName, locale string, data TemplateData) (subject, html, text string, err error) {
	if !supportedLocales[locale] {
		locale = "en"
	}
	subjectMap, ok := subjects[templateName]
	if !ok {
		return "", "", "", fmt.Errorf("Render: unknown template %q", templateName)
	}
	subject = subjectMap[locale]
	if subject == "" {
		subject = subjectMap["en"]
	}

	htmlPath := fmt.Sprintf("templates/%s.%s.html.tmpl", templateName, locale)
	textPath := fmt.Sprintf("templates/%s.%s.txt.tmpl", templateName, locale)

	htmlBytes, err := templatesFS.ReadFile(htmlPath)
	if err != nil {
		return "", "", "", fmt.Errorf("Render: read html: %w", err)
	}
	textBytes, err := templatesFS.ReadFile(textPath)
	if err != nil {
		return "", "", "", fmt.Errorf("Render: read text: %w", err)
	}

	htmlT, err := htmltmpl.New(htmlPath).Parse(string(htmlBytes))
	if err != nil {
		return "", "", "", fmt.Errorf("Render: parse html: %w", err)
	}
	textT, err := texttmpl.New(textPath).Parse(string(textBytes))
	if err != nil {
		return "", "", "", fmt.Errorf("Render: parse text: %w", err)
	}

	var htmlBuf, textBuf bytes.Buffer
	if err := htmlT.Execute(&htmlBuf, data); err != nil {
		return "", "", "", fmt.Errorf("Render: exec html: %w", err)
	}
	if err := textT.Execute(&textBuf, data); err != nil {
		return "", "", "", fmt.Errorf("Render: exec text: %w", err)
	}
	return subject, htmlBuf.String(), strings.TrimRight(textBuf.String(), "\n") + "\n", nil
}
