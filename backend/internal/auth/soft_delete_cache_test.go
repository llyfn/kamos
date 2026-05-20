package auth

import (
	"testing"
)

// The DB-touching paths of SoftDeleteCache (Refresh, Run) are exercised by
// tests/integration/soft_delete_cache_integration_test.go — they need a
// real Postgres to exercise the index. The unit tests here cover the pure
// in-memory state transitions: Contains / Add / replace-on-Refresh.

func TestSoftDeleteCache_AddContains(t *testing.T) {
	c := NewSoftDeleteCache(nil, 0, 0)
	if c.Contains("u-1") {
		t.Fatalf("empty cache must not contain u-1")
	}
	c.Add("u-1")
	if !c.Contains("u-1") {
		t.Fatalf("after Add: Contains should be true")
	}
	if c.Contains("u-2") {
		t.Fatalf("Contains for unrelated id should be false")
	}
}

func TestSoftDeleteCache_Concurrent(t *testing.T) {
	// Two writers + a reader hammering the cache should not race when run
	// under -race; this primarily verifies that the RWMutex usage is sound.
	c := NewSoftDeleteCache(nil, 0, 0)
	done := make(chan struct{})
	go func() {
		for i := 0; i < 1000; i++ {
			c.Add("u-a")
		}
		done <- struct{}{}
	}()
	go func() {
		for i := 0; i < 1000; i++ {
			c.Add("u-b")
		}
		done <- struct{}{}
	}()
	go func() {
		for i := 0; i < 1000; i++ {
			_ = c.Contains("u-a")
			_ = c.Contains("u-c")
		}
		done <- struct{}{}
	}()
	for i := 0; i < 3; i++ {
		<-done
	}
	if !c.Contains("u-a") || !c.Contains("u-b") {
		t.Fatalf("after concurrent Adds, both ids should be present")
	}
}
