// SubcategoryPicker — slim dropdown of the live subcategories under a
// given category slug. Used by CatalogBeverageForm. Renders an empty
// state when no category is selected (the form forces the parent to
// clear `value` when category changes — see the form's onChange).

import { useQuery } from '@tanstack/react-query';
import {
  type CategorySlug,
  listPublicSubcategories,
  type Subcategory,
} from '@/lib/api/subcategories';

interface SubcategoryPickerProps {
  categorySlug: CategorySlug | '';
  value: string | null;
  onChange: (id: string | null) => void;
  label?: string;
  disabled?: boolean;
}

export function SubcategoryPicker({
  categorySlug,
  value,
  onChange,
  label = 'Subcategory (optional)',
  disabled = false,
}: SubcategoryPickerProps) {
  const query = useQuery({
    queryKey: ['public', 'subcategories', categorySlug || 'all'],
    queryFn: async () => {
      if (!categorySlug) return [] as Subcategory[];
      return listPublicSubcategories(categorySlug);
    },
    enabled: Boolean(categorySlug),
    staleTime: 5 * 60 * 1000,
  });

  const options = query.data ?? [];
  const isEmpty = !categorySlug || options.length === 0;

  return (
    <label className="flex flex-col gap-1">
      <span className="text-[color:var(--color-muted)]">{label}</span>
      <select
        value={value ?? ''}
        onChange={(e) => onChange(e.target.value || null)}
        disabled={disabled || !categorySlug}
        className="border border-[color:var(--color-border)] rounded px-2 py-1 bg-[color:var(--color-surface)] disabled:opacity-50"
      >
        <option value="">(none)</option>
        {options.map((s) => (
          <option key={s.id} value={s.id}>
            {s.name.en} ({s.slug})
          </option>
        ))}
      </select>
      {!categorySlug && (
        <span className="text-xs text-[color:var(--color-muted)]">
          pick a category first to see subcategories
        </span>
      )}
      {categorySlug && isEmpty && !query.isLoading && (
        <span className="text-xs text-[color:var(--color-muted)]">
          no subcategories yet — manage from the Subcategories page
        </span>
      )}
    </label>
  );
}
