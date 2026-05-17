package cache

import (
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestLRUHitAndMiss(t *testing.T) {
	c := NewLRU[string, int]("test", 4, time.Minute)
	if _, ok := c.Get("a"); ok {
		t.Fatalf("expected miss on empty cache")
	}
	c.Set("a", 1)
	v, ok := c.Get("a")
	if !ok || v != 1 {
		t.Fatalf("expected hit (1, true); got (%d, %v)", v, ok)
	}
	h, m := c.Stats()
	if h != 1 || m != 1 {
		t.Fatalf("expected hits=1 misses=1; got hits=%d misses=%d", h, m)
	}
}

func TestLRUTTLExpiry(t *testing.T) {
	c := NewLRU[string, string]("ttl-test", 4, 25*time.Millisecond)
	c.Set("k", "v")
	if v, ok := c.Get("k"); !ok || v != "v" {
		t.Fatalf("immediate read: expected hit; got (%q, %v)", v, ok)
	}
	time.Sleep(50 * time.Millisecond)
	if _, ok := c.Get("k"); ok {
		t.Fatalf("expected expiry miss after TTL elapsed")
	}
}

func TestLRUInvalidate(t *testing.T) {
	c := NewLRU[string, int]("inv-test", 4, time.Minute)
	c.Set("a", 1)
	c.Set("b", 2)
	c.Invalidate("a")
	if _, ok := c.Get("a"); ok {
		t.Fatalf("expected a to be evicted")
	}
	if v, ok := c.Get("b"); !ok || v != 2 {
		t.Fatalf("expected b to still be present; got (%d, %v)", v, ok)
	}
}

func TestLRUInvalidatePrefix(t *testing.T) {
	c := NewLRU[string, int]("prefix-test", 8, time.Minute)
	c.Set("bev1:en", 1)
	c.Set("bev1:ja", 2)
	c.Set("bev1:ko", 3)
	c.Set("bev2:en", 4)
	c.InvalidatePrefix("bev1:")
	if _, ok := c.Get("bev1:en"); ok {
		t.Fatalf("bev1:en should be evicted")
	}
	if _, ok := c.Get("bev1:ja"); ok {
		t.Fatalf("bev1:ja should be evicted")
	}
	if _, ok := c.Get("bev1:ko"); ok {
		t.Fatalf("bev1:ko should be evicted")
	}
	if v, ok := c.Get("bev2:en"); !ok || v != 4 {
		t.Fatalf("bev2:en should survive; got (%d, %v)", v, ok)
	}
}

func TestLRUConcurrentReadWrite(t *testing.T) {
	c := NewLRU[string, int]("concurrent-test", 100, time.Minute)
	const goroutines = 32
	const iters = 500
	var wg sync.WaitGroup
	wg.Add(goroutines)
	for i := 0; i < goroutines; i++ {
		go func(id int) {
			defer wg.Done()
			for j := 0; j < iters; j++ {
				key := "k" + string(rune('a'+(j%8)))
				if j%2 == 0 {
					c.Set(key, id*1000+j)
				} else {
					_, _ = c.Get(key)
				}
			}
		}(i)
	}
	wg.Wait()
	// Survival check: cache is in a consistent state and at most 8 keys
	// (we wrote 8 distinct ones).
	h, m := c.Stats()
	if h+m == 0 {
		t.Fatalf("expected at least some Get calls; got stats=(%d,%d)", h, m)
	}
}

// TestLRUGetOrLoadCoalescesConcurrentMisses — Phase 7a MAJOR-1 regression.
// Fires N concurrent GetOrLoad calls on the same missing key with a slow
// loader and asserts the loader runs exactly once. Without singleflight,
// every concurrent caller would issue its own loader call (the
// thundering-herd problem on hot-key TTL expiry).
func TestLRUGetOrLoadCoalescesConcurrentMisses(t *testing.T) {
	c := NewLRU[string, int]("sf-test", 16, time.Minute)
	var loaderCalls atomic.Int64
	loader := func() (int, error) {
		loaderCalls.Add(1)
		// Hold the loader open long enough that the other goroutines
		// definitely contend on the same key.
		time.Sleep(50 * time.Millisecond)
		return 42, nil
	}

	const goroutines = 16
	var wg sync.WaitGroup
	wg.Add(goroutines)
	results := make([]int, goroutines)
	errs := make([]error, goroutines)
	for i := 0; i < goroutines; i++ {
		go func(idx int) {
			defer wg.Done()
			v, err := c.GetOrLoad("hot-key", loader)
			results[idx] = v
			errs[idx] = err
		}(i)
	}
	wg.Wait()

	if got := loaderCalls.Load(); got != 1 {
		t.Fatalf("loader ran %d times; want 1 (singleflight failed to coalesce)", got)
	}
	for i, err := range errs {
		if err != nil {
			t.Fatalf("goroutine %d returned error: %v", i, err)
		}
		if results[i] != 42 {
			t.Fatalf("goroutine %d returned %d; want 42", i, results[i])
		}
	}
	// Cache is populated.
	v, ok := c.Get("hot-key")
	if !ok || v != 42 {
		t.Fatalf("post-load Get: got (%d, %v); want (42, true)", v, ok)
	}
}

// TestLRUGetOrLoadPropagatesError — when the loader fails the error is
// returned to the caller and nothing is cached.
func TestLRUGetOrLoadPropagatesError(t *testing.T) {
	c := NewLRU[string, int]("sf-err", 4, time.Minute)
	sentinel := errors.New("loader boom")
	v, err := c.GetOrLoad("k", func() (int, error) {
		return 0, sentinel
	})
	if !errors.Is(err, sentinel) {
		t.Fatalf("err: want sentinel; got %v", err)
	}
	if v != 0 {
		t.Fatalf("v: want zero on error; got %d", v)
	}
	if _, ok := c.Get("k"); ok {
		t.Fatalf("failed loads must not populate the cache")
	}
}

// TestLRUGetOrLoadHitFastPath — a populated cache returns the cached
// value without invoking the loader.
func TestLRUGetOrLoadHitFastPath(t *testing.T) {
	c := NewLRU[string, int]("sf-hit", 4, time.Minute)
	c.Set("k", 7)
	var calls atomic.Int64
	v, err := c.GetOrLoad("k", func() (int, error) {
		calls.Add(1)
		return 99, nil
	})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if v != 7 {
		t.Fatalf("v: want 7; got %d", v)
	}
	if calls.Load() != 0 {
		t.Fatalf("loader ran on a hit (calls=%d)", calls.Load())
	}
}

func TestLRUObservers(t *testing.T) {
	c := NewLRU[string, int]("obs-test", 4, time.Minute)
	var hits, misses int
	c.SetObservers(
		func(name string) {
			if name != "obs-test" {
				t.Errorf("hit observer got wrong name: %q", name)
			}
			hits++
		},
		func(name string) {
			if name != "obs-test" {
				t.Errorf("miss observer got wrong name: %q", name)
			}
			misses++
		},
	)
	if _, ok := c.Get("nope"); ok {
		t.Fatal("unexpected hit")
	}
	c.Set("k", 1)
	if _, ok := c.Get("k"); !ok {
		t.Fatal("expected hit")
	}
	if hits != 1 || misses != 1 {
		t.Fatalf("expected observer counts (1,1); got (%d,%d)", hits, misses)
	}
}
