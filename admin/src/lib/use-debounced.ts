// Tiny generic debounce hook. Returns the input value held for `ms`
// milliseconds before propagating downstream — used by the catalog
// list pages to defer the FTS query while the operator is still typing.

import { useEffect, useState } from 'react';

export function useDebounced<T>(value: T, ms = 300): T {
  const [debounced, setDebounced] = useState<T>(value);
  useEffect(() => {
    const handle = setTimeout(() => setDebounced(value), ms);
    return () => clearTimeout(handle);
  }, [value, ms]);
  return debounced;
}
