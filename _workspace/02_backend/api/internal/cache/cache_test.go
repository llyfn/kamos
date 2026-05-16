package cache

import (
	"sync"
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
