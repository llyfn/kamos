// Create/edit form for a catalog beverage. Mirrors the validators in
// backend/internal/handlers/admin.go (AdminBeverageCreate/Update):
//
//   * name_i18n.en + name_i18n.ja required, ko optional, each ≤ 200
//   * producer_id required (UUID); category driven by category_slug
//   * abv: 0–60 (step 0.1), nullable
//   * polishing_ratio: 0–100 integer, NIHONSHU ONLY (server CHECK)
//   * flavor_profile: array of slugs, ≤ 8 chips
//   * description_i18n: each locale ≤ 2000
//   * label_image_url: https only, ≤ 512
//
// Migration 016: beverages no longer carry their own prefecture/region —
// they derive geography from `producer.prefecture`, so this form has no
// prefecture inputs. To change a beverage's prefecture, edit its producer.
//
// The form drives `category_slug`; the server resolves it to the
// canonical category row. The producer picker hits the same
// /v1/admin/producers typeahead used by the filter bar. The category
// list and flavor-tag list come from the public taxonomy endpoints
// (cached forever in the browser).

import { useQuery } from '@tanstack/react-query';
import { type FormEvent, type KeyboardEvent, useState } from 'react';
import {
  ProducerPicker,
  type ProducerPickerValue,
  preferredName,
} from '@/components/ProducerPicker';
import { SubcategoryPicker } from '@/components/SubcategoryPicker';
import { api } from '@/lib/api';
import type { components } from '@/types/api';

type AdminBeverage = components['schemas']['AdminBeverage'];
type Body = components['schemas']['AdminBeverageCreate'];
type CategoryLabel = components['schemas']['CategoryLabel'];
type CategorySlug = CategoryLabel['slug'];

// Fallback taxonomy if /v1/categories is unreachable. Slugs match the SPEC
// §2.1 canonical strings. The slug drives both the submission body and
// the polishing_ratio toggle.
const FALLBACK_CATEGORIES: CategoryLabel[] = [
  { slug: 'nihonshu', label_i18n: { en: 'Nihonshu (Sake)', ja: '日本酒', ko: '니혼슈 (사케)' } },
  { slug: 'shochu', label_i18n: { en: 'Shochu', ja: '焼酎', ko: '쇼츄' } },
  { slug: 'liqueur', label_i18n: { en: 'Liqueur', ja: 'リキュール', ko: '리큐어' } },
];

// Loose seed shape used by callers that don't have a full AdminBeverage
// (e.g. the approval queue, which constructs an initial from the user's
// free-form JSONB request payload). `initial` always wins when set.
export interface CatalogBeverageFormPartial {
  producer_id?: string;
  producer_label?: string;
  category_slug?: CategorySlug | '';
  subcategory_id?: string | null;
  name_en?: string;
  name_ja?: string;
  name_ko?: string;
  abv?: string;
  polishing_ratio?: string;
  flavor_profile?: string[];
  description_en?: string;
  description_ja?: string;
  description_ko?: string;
  label_image_url?: string;
}

interface CatalogBeverageFormProps {
  initial?: AdminBeverage | null;
  initialPartial?: CatalogBeverageFormPartial;
  submitting?: boolean;
  submitLabel?: string;
  errorMessage?: string | null;
  onSubmit: (body: Body) => void;
  onCancel: () => void;
}

interface FormState {
  producer: ProducerPickerValue | null;
  category_slug: CategorySlug | '';
  subcategory_id: string | null;
  name_en: string;
  name_ja: string;
  name_ko: string;
  abv: string;
  polishing_ratio: string;
  flavor_profile: string[];
  flavor_draft: string;
  description_en: string;
  description_ja: string;
  description_ko: string;
  label_image_url: string;
}

// The initial-edit AdminBeverage carries category.slug, which is also
// what the server now accepts on create/update — no UUID lookup needed.
// When `b` is absent the form falls through to `p`, a loose partial
// used by the approval queue to seed the form from the user's free-form
// JSONB request payload.
function initialState(
  b: AdminBeverage | null | undefined,
  p: CatalogBeverageFormPartial | undefined,
): FormState {
  if (b) {
    // Slice C: prefer the canonical subcategory.id; the dual-source
    // fallback (id="") means "show legacy text only" — surface that as
    // null in the picker so the admin can pick a real row.
    const subId = b.subcategory?.id ? b.subcategory.id : null;
    return {
      producer: { id: b.producer.id, label: preferredName(b.producer.name) },
      category_slug: b.category.slug,
      subcategory_id: subId,
      name_en: b.name.en ?? '',
      name_ja: b.name.ja ?? '',
      name_ko: b.name.ko ?? '',
      abv: b.abv != null ? String(b.abv) : '',
      polishing_ratio: b.polishing_ratio != null ? String(b.polishing_ratio) : '',
      flavor_profile: b.flavor_profile ?? [],
      flavor_draft: '',
      description_en: b.description?.en ?? '',
      description_ja: b.description?.ja ?? '',
      description_ko: b.description?.ko ?? '',
      label_image_url: b.label_image_url ?? '',
    };
  }
  return {
    producer: p?.producer_id ? { id: p.producer_id, label: p.producer_label ?? '' } : null,
    category_slug: p?.category_slug ?? '',
    subcategory_id: p?.subcategory_id ?? null,
    name_en: p?.name_en ?? '',
    name_ja: p?.name_ja ?? '',
    name_ko: p?.name_ko ?? '',
    abv: p?.abv ?? '',
    polishing_ratio: p?.polishing_ratio ?? '',
    flavor_profile: p?.flavor_profile ?? [],
    flavor_draft: '',
    description_en: p?.description_en ?? '',
    description_ja: p?.description_ja ?? '',
    description_ko: p?.description_ko ?? '',
    label_image_url: p?.label_image_url ?? '',
  };
}

export function CatalogBeverageForm({
  initial,
  initialPartial,
  submitting = false,
  submitLabel = 'Save',
  errorMessage,
  onSubmit,
  onCancel,
}: CatalogBeverageFormProps) {
  const [form, setForm] = useState<FormState>(() => initialState(initial, initialPartial));
  const [localError, setLocalError] = useState<string | null>(null);

  // Categories — the public /v1/categories returns slugs + locale labels.
  // The admin create/update endpoints accept `category_slug` directly, so
  // the dropdown is the single source of truth.
  const categoriesQuery = useQuery({
    queryKey: ['taxonomy', 'categories'],
    queryFn: async () => {
      const { data, error } = await api.GET('/v1/categories');
      if (error || !data) return FALLBACK_CATEGORIES;
      return data;
    },
    staleTime: 60 * 60 * 1000,
  });

  const flavorTagsQuery = useQuery({
    queryKey: ['taxonomy', 'flavor-tags'],
    queryFn: async () => {
      const { data, error } = await api.GET('/v1/flavor-tags');
      if (error || !data) return [];
      return data;
    },
    staleTime: 60 * 60 * 1000,
  });

  const categories: CategoryLabel[] = categoriesQuery.data ?? FALLBACK_CATEGORIES;
  const flavorSlugs: string[] = (flavorTagsQuery.data ?? []).map((t) => t.slug);

  function set<K extends keyof FormState>(key: K, value: FormState[K]) {
    setForm((prev) => ({ ...prev, [key]: value }));
  }

  function addFlavor(raw: string) {
    const slug = raw.trim().toLowerCase().replace(/\s+/g, '_');
    if (!slug) return;
    if (form.flavor_profile.includes(slug)) {
      setForm((prev) => ({ ...prev, flavor_draft: '' }));
      return;
    }
    if (form.flavor_profile.length >= 8) {
      setLocalError('Flavor profile may contain at most 8 entries.');
      return;
    }
    if (slug.length > 32) {
      setLocalError('Each flavor tag must be ≤ 32 characters.');
      return;
    }
    setForm((prev) => ({
      ...prev,
      flavor_profile: [...prev.flavor_profile, slug],
      flavor_draft: '',
    }));
  }

  function removeFlavor(slug: string) {
    setForm((prev) => ({
      ...prev,
      flavor_profile: prev.flavor_profile.filter((s) => s !== slug),
    }));
  }

  function onFlavorKey(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'Enter' || e.key === ',') {
      e.preventDefault();
      addFlavor(form.flavor_draft);
    }
  }

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setLocalError(null);
    if (!form.producer) {
      setLocalError('Producer is required.');
      return;
    }
    if (!form.category_slug) {
      setLocalError('Category is required.');
      return;
    }
    const en = form.name_en.trim();
    const ja = form.name_ja.trim();
    if (!en || !ja) {
      setLocalError('Name (English) and Name (Japanese) are required.');
      return;
    }
    const ko = form.name_ko.trim();

    const body: Body = {
      producer_id: form.producer.id,
      category_slug: form.category_slug,
      name_i18n: ko ? { en, ja, ko } : { en, ja },
    };
    // Slice C: subcategory_id flow. Always emit the field so the PATCH
    // path can clear it (empty string) when the user picked (none). On
    // create the empty string is harmless — the server treats it as
    // "no subcategory" (the same as omitting).
    body.subcategory_id = form.subcategory_id ?? '';
    if (form.abv.trim()) {
      const n = Number(form.abv);
      if (Number.isNaN(n) || n < 0 || n > 60) {
        setLocalError('ABV must be between 0 and 60.');
        return;
      }
      body.abv = n;
    }
    if (form.category_slug === 'nihonshu' && form.polishing_ratio.trim()) {
      const n = Number(form.polishing_ratio);
      if (!Number.isInteger(n) || n < 0 || n > 100) {
        setLocalError('Polishing ratio must be an integer between 0 and 100.');
        return;
      }
      body.polishing_ratio = n;
    }
    if (form.flavor_profile.length > 0) body.flavor_profile = form.flavor_profile;
    const descEn = form.description_en.trim();
    const descJa = form.description_ja.trim();
    const descKo = form.description_ko.trim();
    if (descEn || descJa || descKo) {
      const desc: components['schemas']['I18nText'] = { en: descEn };
      if (descJa) desc.ja = descJa;
      if (descKo) desc.ko = descKo;
      body.description_i18n = desc;
    }
    if (form.label_image_url.trim()) {
      const url = form.label_image_url.trim();
      if (!url.startsWith('https://')) {
        setLocalError('Label image URL must start with https://.');
        return;
      }
      if (url.length > 512) {
        setLocalError('Label image URL must be ≤ 512 characters.');
        return;
      }
      body.label_image_url = url;
    }
    onSubmit(body);
  }

  const showPolishing = form.category_slug === 'nihonshu';

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

      <ProducerPicker
        value={form.producer}
        onChange={(v) => set('producer', v)}
        label="Producer"
        required
      />

      <label className="flex flex-col gap-1">
        <span className="text-[color:var(--color-muted)]">Category *</span>
        <select
          value={form.category_slug}
          onChange={(e) => {
            const next = e.target.value as CategorySlug | '';
            // Changing the category invalidates the current subcategory
            // (subcategory_id is FK-scoped to category_id). Clear it so
            // the user has to repick from the now-filtered dropdown.
            setForm((prev) => ({ ...prev, category_slug: next, subcategory_id: null }));
          }}
          required
          className="border border-[color:var(--color-border)] rounded px-2 py-1 bg-[color:var(--color-surface)]"
        >
          <option value="">(select)</option>
          {categories.map((c) => (
            <option key={c.slug} value={c.slug}>
              {c.label_i18n.en}
            </option>
          ))}
        </select>
      </label>

      <SubcategoryPicker
        categorySlug={form.category_slug}
        value={form.subcategory_id}
        onChange={(id) => set('subcategory_id', id)}
      />

      <TextField
        label="ABV % (optional, 0–60)"
        value={form.abv}
        onChange={(v) => set('abv', v)}
        type="number"
        min={0}
        max={60}
        step={0.1}
      />
      {showPolishing && (
        <TextField
          label="Polishing ratio % (optional, 0–100, Nihonshu only)"
          value={form.polishing_ratio}
          onChange={(v) => set('polishing_ratio', v)}
          type="number"
          min={0}
          max={100}
          step={1}
        />
      )}

      <div className="flex flex-col gap-1">
        <span className="text-[color:var(--color-muted)]">
          Flavor profile (optional, up to 8 slugs)
        </span>
        <div className="flex flex-wrap gap-1 mb-1">
          {form.flavor_profile.map((s) => (
            <span
              key={s}
              className="inline-flex items-center gap-1 px-2 py-0.5 bg-[color:var(--color-bg)] border border-[color:var(--color-border)] rounded text-xs"
            >
              {s}
              <button
                type="button"
                onClick={() => removeFlavor(s)}
                className="text-[color:var(--color-muted)] hover:text-[color:var(--color-fg)]"
                aria-label={`Remove ${s}`}
              >
                ✕
              </button>
            </span>
          ))}
        </div>
        <input
          type="text"
          value={form.flavor_draft}
          onChange={(e) => set('flavor_draft', e.target.value)}
          onKeyDown={onFlavorKey}
          onBlur={() => {
            if (form.flavor_draft.trim()) addFlavor(form.flavor_draft);
          }}
          list="flavor-taxonomy"
          placeholder="type slug + Enter or comma"
          maxLength={32}
          className="border border-[color:var(--color-border)] rounded px-2 py-1"
        />
        {flavorSlugs.length > 0 && (
          <datalist id="flavor-taxonomy">
            {flavorSlugs.map((s) => (
              <option key={s} value={s} />
            ))}
          </datalist>
        )}
      </div>

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

      <TextField
        label="Label image URL (optional, https only, ≤512)"
        value={form.label_image_url}
        onChange={(v) => set('label_image_url', v)}
        type="url"
        maxLength={512}
        placeholder="https://…"
      />

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
