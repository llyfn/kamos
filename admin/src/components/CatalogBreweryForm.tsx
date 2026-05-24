// Create/edit form for a catalog brewery. The parent owns the modal
// shell and the mutation hook; this component is a pure controlled
// form that emits a normalized AdminBreweryCreate/Update body via
// onSubmit. Constraints mirror backend/internal/handlers/admin.go:
//
//   * name_i18n.en + name_i18n.ja required, ko optional, each ≤ 200
//   * prefecture_slug: optional; resolved against GET /v1/reference/regions.
//     Create: omit / empty = no prefecture; non-empty slug = set.
//     Update: empty string (`""`) explicitly clears to NULL; slug sets it.
//     Unknown slug → 422 INVALID_PREFECTURE_SLUG (surfaced inline).
//   * founded_year: optional integer in 800..2100
//   * website: optional URL (http or https accepted), ≤ 512
//   * description_i18n: optional, each locale ≤ 2000

import { useQuery } from '@tanstack/react-query';
import { type FormEvent, useState } from 'react';
import { preferredName } from '@/components/BreweryPicker';
import { api } from '@/lib/api';
import type { components } from '@/types/api';

type AdminBrewery = components['schemas']['AdminBrewery'];
type CreateBody = components['schemas']['AdminBreweryCreate'];
type UpdateBody = components['schemas']['AdminBreweryUpdate'];
type RegionWithPrefectures = components['schemas']['RegionWithPrefectures'];

interface CatalogBreweryFormProps {
  initial?: AdminBrewery | null;
  submitting?: boolean;
  submitLabel?: string;
  errorMessage?: string | null;
  // Update bodies need the tri-state `prefecture_slug` (omit vs "" vs slug).
  // Create bodies omit when empty. The parent decides which mutation to call;
  // we hand back a union and the caller narrows.
  onSubmit: (body: CreateBody | UpdateBody) => void;
  onCancel: () => void;
}

interface FormState {
  name_en: string;
  name_ja: string;
  name_ko: string;
  prefecture_slug: string;
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
    prefecture_slug: b?.prefecture?.slug ?? '',
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

  // /v1/reference/regions is public, no auth, Cache-Control max-age=3600.
  // Effectively immutable seed data; cache aggressively in-process too.
  const regionsQuery = useQuery({
    queryKey: ['taxonomy', 'regions'],
    queryFn: async () => {
      const { data, error } = await api.GET('/v1/reference/regions');
      if (error || !data) return [] as RegionWithPrefectures[];
      return data;
    },
    staleTime: 60 * 60 * 1000,
  });

  const regions: RegionWithPrefectures[] = regionsQuery.data ?? [];

  // Surface the backend's typed-422 inline against the prefecture select
  // so the user can see *why* "save" failed. Matches the inline-field-
  // error pattern used by CatalogBeverageForm.
  const isInvalidPrefecture = errorMessage === 'INVALID_PREFECTURE_SLUG';

  const isEdit = initial != null;

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

    // The two schemas diverge in their prefecture_slug semantics, so build
    // and emit them separately rather than fight the union shape.
    if (isEdit) {
      const body: UpdateBody = {
        name_i18n: ko ? { en, ja, ko } : { en, ja },
      };
      // Edit always sends prefecture_slug: a slug to set, "" to clear.
      // The user's current selection is the desired final state.
      body.prefecture_slug = form.prefecture_slug;
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
      return;
    }

    const body: CreateBody = {
      name_i18n: ko ? { en, ja, ko } : { en, ja },
    };
    // Create omits the key entirely when no prefecture chosen.
    if (form.prefecture_slug) body.prefecture_slug = form.prefecture_slug;
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

      <label className="flex flex-col gap-1">
        <span className="text-[color:var(--color-muted)]">
          Prefecture (optional)
          {isEdit ? <span className="ml-1 text-xs">— select "(none)" to clear.</span> : null}
        </span>
        <select
          value={form.prefecture_slug}
          onChange={(e) => set('prefecture_slug', e.target.value)}
          disabled={regionsQuery.isLoading}
          aria-invalid={isInvalidPrefecture}
          className="border border-[color:var(--color-border)] rounded px-2 py-1 bg-[color:var(--color-surface)]"
        >
          <option value="">(none)</option>
          {regions.map((r) => (
            <optgroup key={r.id} label={preferredName(r.name)}>
              {r.prefectures.map((p) => (
                <option key={p.id} value={p.slug}>
                  {preferredName(p.name)}
                </option>
              ))}
            </optgroup>
          ))}
        </select>
        {isInvalidPrefecture && (
          <span className="text-red-700 text-xs">
            Unknown prefecture slug. Pick one from the list.
          </span>
        )}
      </label>

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

      {(localError || (errorMessage && !isInvalidPrefecture)) && (
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
