// Create/edit form for a catalog brewery. The parent owns the modal
// shell and the mutation hook; this component is a pure controlled
// form that emits a normalized AdminBreweryCreate/Update body via
// onSubmit. Constraints mirror backend/internal/handlers/admin.go:
//
//   * name_i18n.en + name_i18n.ja required, ko optional, each ≤ 200
//   * prefecture / region: optional, ≤ 100
//   * founded_year: optional integer in 800..2100
//   * website: optional URL (http or https accepted), ≤ 512
//   * description_i18n: optional, each locale ≤ 2000

import { type FormEvent, useState } from 'react';
import type { components } from '@/types/api';

type AdminBrewery = components['schemas']['AdminBrewery'];
type Body = components['schemas']['AdminBreweryCreate'];

interface CatalogBreweryFormProps {
  initial?: AdminBrewery | null;
  submitting?: boolean;
  submitLabel?: string;
  errorMessage?: string | null;
  onSubmit: (body: Body) => void;
  onCancel: () => void;
}

interface FormState {
  name_en: string;
  name_ja: string;
  name_ko: string;
  prefecture: string;
  region: string;
  founded_year: string;
  website: string;
  description_en: string;
  description_ja: string;
  description_ko: string;
}

function initialState(b: AdminBrewery | null | undefined): FormState {
  return {
    name_en: b?.name.en ?? '',
    name_ja: b?.name.ja ?? '',
    name_ko: b?.name.ko ?? '',
    prefecture: b?.prefecture ?? '',
    region: b?.region ?? '',
    founded_year: b?.founded_year != null ? String(b.founded_year) : '',
    website: b?.website ?? '',
    description_en: b?.description?.en ?? '',
    description_ja: b?.description?.ja ?? '',
    description_ko: b?.description?.ko ?? '',
  };
}

export function CatalogBreweryForm({
  initial,
  submitting = false,
  submitLabel = 'Save',
  errorMessage,
  onSubmit,
  onCancel,
}: CatalogBreweryFormProps) {
  const [form, setForm] = useState<FormState>(() => initialState(initial));
  const [localError, setLocalError] = useState<string | null>(null);

  function set<K extends keyof FormState>(key: K, value: FormState[K]) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setLocalError(null);
    const en = form.name_en.trim();
    const ja = form.name_ja.trim();
    if (!en || !ja) {
      setLocalError('Name (English) and Name (Japanese) are required.');
      return;
    }
    const ko = form.name_ko.trim();
    const body: Body = {
      name_i18n: ko ? { en, ja, ko } : { en, ja },
    };
    if (form.prefecture.trim()) body.prefecture = form.prefecture.trim();
    if (form.region.trim()) body.region = form.region.trim();
    if (form.founded_year.trim()) {
      const n = Number(form.founded_year);
      if (!Number.isInteger(n) || n < 800 || n > 2100) {
        setLocalError('Founded year must be an integer between 800 and 2100.');
        return;
      }
      body.founded_year = n;
    }
    if (form.website.trim()) body.website = form.website.trim();
    const descEn = form.description_en.trim();
    const descJa = form.description_ja.trim();
    const descKo = form.description_ko.trim();
    if (descEn || descJa || descKo) {
      const desc: components['schemas']['I18nText'] = { en: descEn };
      if (descJa) desc.ja = descJa;
      if (descKo) desc.ko = descKo;
      body.description_i18n = desc;
    }
    onSubmit(body);
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-3 text-sm">
      <fieldset className="flex flex-col gap-2 border border-[color:var(--color-border)] rounded p-3">
        <legend className="px-1 text-[color:var(--color-muted)]">Name</legend>
        <TextField
          label="English *"
          value={form.name_en}
          onChange={(v) => set('name_en', v)}
          maxLength={200}
          required
        />
        <TextField
          label="Japanese *"
          value={form.name_ja}
          onChange={(v) => set('name_ja', v)}
          maxLength={200}
          required
        />
        <TextField
          label="Korean (optional)"
          value={form.name_ko}
          onChange={(v) => set('name_ko', v)}
          maxLength={200}
        />
      </fieldset>

      <TextField
        label="Prefecture (optional)"
        value={form.prefecture}
        onChange={(v) => set('prefecture', v)}
        maxLength={100}
      />
      <TextField
        label="Region (optional)"
        value={form.region}
        onChange={(v) => set('region', v)}
        maxLength={100}
      />
      <TextField
        label="Founded year (optional, 800–2100)"
        value={form.founded_year}
        onChange={(v) => set('founded_year', v)}
        type="number"
        min={800}
        max={2100}
        step={1}
      />
      <TextField
        label="Website (optional, http or https)"
        value={form.website}
        onChange={(v) => set('website', v)}
        maxLength={512}
        type="url"
        placeholder="https://example.com"
      />

      <fieldset className="flex flex-col gap-2 border border-[color:var(--color-border)] rounded p-3">
        <legend className="px-1 text-[color:var(--color-muted)]">Description (optional)</legend>
        <TextAreaField
          label="English"
          value={form.description_en}
          onChange={(v) => set('description_en', v)}
          maxLength={2000}
        />
        <TextAreaField
          label="Japanese"
          value={form.description_ja}
          onChange={(v) => set('description_ja', v)}
          maxLength={2000}
        />
        <TextAreaField
          label="Korean"
          value={form.description_ko}
          onChange={(v) => set('description_ko', v)}
          maxLength={2000}
        />
      </fieldset>

      {(localError || errorMessage) && (
        <p className="text-red-700 text-xs">{localError ?? errorMessage}</p>
      )}
      <div className="flex justify-end gap-2 mt-2">
        <button
          type="button"
          onClick={onCancel}
          className="px-3 py-1 border border-[color:var(--color-border)] rounded"
        >
          Cancel
        </button>
        <button
          type="submit"
          disabled={submitting}
          className="px-3 py-1 bg-[color:var(--color-accent)] text-white rounded disabled:opacity-50"
        >
          {submitting ? 'Saving…' : submitLabel}
        </button>
      </div>
    </form>
  );
}

interface TextFieldProps {
  label: string;
  value: string;
  onChange: (v: string) => void;
  required?: boolean;
  type?: string;
  maxLength?: number;
  min?: number;
  max?: number;
  step?: number;
  placeholder?: string;
}

function TextField({
  label,
  value,
  onChange,
  required,
  type = 'text',
  maxLength,
  min,
  max,
  step,
  placeholder,
}: TextFieldProps) {
  return (
    <label className="flex flex-col gap-1">
      <span className="text-[color:var(--color-muted)]">{label}</span>
      <input
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        required={required ?? false}
        maxLength={maxLength}
        min={min}
        max={max}
        step={step}
        placeholder={placeholder}
        className="border border-[color:var(--color-border)] rounded px-2 py-1"
      />
    </label>
  );
}

interface TextAreaFieldProps {
  label: string;
  value: string;
  onChange: (v: string) => void;
  maxLength?: number;
}

function TextAreaField({ label, value, onChange, maxLength }: TextAreaFieldProps) {
  return (
    <label className="flex flex-col gap-1">
      <span className="text-[color:var(--color-muted)]">{label}</span>
      <textarea
        value={value}
        onChange={(e) => onChange(e.target.value)}
        maxLength={maxLength}
        rows={3}
        className="border border-[color:var(--color-border)] rounded px-2 py-1"
      />
    </label>
  );
}
