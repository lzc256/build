#!/bin/bash
# Adds a magpie-style privacy masking dashboard to the patched new-api tree.
# Runs after 001-privacy-masking.sh. Stores only redaction metadata (kind,
# placeholder, head, length, request context) in a JSONL file; never values.

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <new-api-source-dir>" >&2
    exit 1
fi

TARGET="$(cd "$1" && pwd)"

echo "========================================="
echo "Patch: privacy-masking dashboard"
echo "Target: $TARGET"
echo "========================================="

for required in "$TARGET/privacy/middleware.go" "$TARGET/internal/privacy/redact/redact.go"; do
    if [ ! -f "$required" ]; then
        echo "Missing $required; run 001-privacy-masking.sh first" >&2
        exit 1
    fi
done

# ------------------------------------------------------------- backend ----
cat > "$TARGET/privacy/insights.go" <<'PGO'
package privacy

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

// MaskEvent is one magpie hit. It deliberately contains no raw value: Head
// and Len are magpie's Hint, and Placeholder is the token sent upstream.
type MaskEvent struct {
	ID          string    `json:"id"`
	Time        time.Time `json:"time"`
	RequestID   string    `json:"request_id"`
	Path        string    `json:"path"`
	Model       string    `json:"model,omitempty"`
	UserID      string    `json:"user_id,omitempty"`
	Kind        string    `json:"kind"`
	By          string    `json:"by"`
	Action      string    `json:"action,omitempty"`
	Placeholder string    `json:"placeholder"`
	Head        string    `json:"head"`
	Len         int       `json:"len"`
}

// InsightSummary is the small aggregate the dashboard needs.
type InsightSummary struct {
	Days     int            `json:"days"`
	Total    int            `json:"total"`
	Requests int            `json:"requests"`
	ByKind   map[string]int `json:"by_kind"`
	ByDay    map[string]int `json:"by_day"`
	ByModel  map[string]int `json:"by_model"`
}

type insightStore struct {
	mu        sync.RWMutex
	path      string
	retention time.Duration
	maxLines  int
}

var (
	insights   = newInsightStore()
	requestSeq uint64
)

func newInsightStore() *insightStore {
	path := os.Getenv("PRIVACY_INSIGHTS_PATH")
	if path == "" {
		path = filepath.Join("data", "privacy-masking.jsonl")
	}
	s := &insightStore{
		path:      path,
		retention: 30 * 24 * time.Hour,
		maxLines:  100000,
	}
	go s.cleanupLoop()
	return s
}

func nextRequestID() string {
	return fmt.Sprintf("%d-%d", time.Now().UnixNano(), atomic.AddUint64(&requestSeq, 1))
}

func (s *insightStore) record(e MaskEvent) {
	if e.ID == "" {
		e.ID = fmt.Sprintf("%d-%d", time.Now().UnixNano(), atomic.AddUint64(&requestSeq, 1))
	}
	if e.Time.IsZero() {
		e.Time = time.Now()
	}
	line, err := json.Marshal(e)
	if err != nil {
		return
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	if err := os.MkdirAll(filepath.Dir(s.path), 0o755); err != nil {
		return
	}
	f, err := os.OpenFile(s.path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = f.Write(append(line, '\n'))
}

func (s *insightStore) cleanupLoop() {
	ticker := time.NewTicker(time.Hour)
	defer ticker.Stop()
	s.cleanup()
	for range ticker.C {
		s.cleanup()
	}
}

func (s *insightStore) cleanup() {
	s.mu.Lock()
	defer s.mu.Unlock()

	f, err := os.Open(s.path)
	if err != nil {
		return
	}
	defer f.Close()

	cutoff := time.Now().Add(-s.retention)
	lines := make([]string, 0)
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	for scanner.Scan() {
		line := scanner.Text()
		var e MaskEvent
		if json.Unmarshal([]byte(line), &e) == nil && e.Time.After(cutoff) {
			lines = append(lines, line)
		}
	}
	if len(lines) > s.maxLines {
		lines = lines[len(lines)-s.maxLines:]
	}

	tmp := s.path + ".tmp"
	content := strings.Join(lines, "\n")
	if content != "" {
		content += "\n"
	}
	if err := os.WriteFile(tmp, []byte(content), 0o600); err != nil {
		return
	}
	_ = os.Rename(tmp, s.path)
}

func (s *insightStore) events(days int, kind string, limit int) ([]MaskEvent, error) {
	if days <= 0 {
		days = 7
	}
	cutoff := time.Now().Add(-time.Duration(days) * 24 * time.Hour)

	s.mu.RLock()
	defer s.mu.RUnlock()

	f, err := os.Open(s.path)
	if err != nil {
		if os.IsNotExist(err) {
			return []MaskEvent{}, nil
		}
		return nil, err
	}
	defer f.Close()

	out := make([]MaskEvent, 0)
	scanner := bufio.NewScanner(f)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	for scanner.Scan() {
		var e MaskEvent
		if json.Unmarshal(scanner.Bytes(), &e) != nil {
			continue
		}
		if e.Time.Before(cutoff) {
			continue
		}
		if kind != "" && e.Kind != kind {
			continue
		}
		out = append(out, e)
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}

	sort.Slice(out, func(i, j int) bool { return out[i].Time.After(out[j].Time) })
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

func (s *insightStore) summary(days int) (InsightSummary, error) {
	all, err := s.events(days, "", 0)
	if err != nil {
		return InsightSummary{}, err
	}
	res := InsightSummary{
		Days:    days,
		Total:   len(all),
		ByKind:  map[string]int{},
		ByDay:   map[string]int{},
		ByModel: map[string]int{},
	}
	requests := map[string]struct{}{}
	for _, e := range all {
		requests[e.RequestID] = struct{}{}
		res.ByKind[e.Kind]++
		res.ByDay[e.Time.Format("2006-01-02")]++
		if e.Model != "" {
			res.ByModel[e.Model]++
		}
	}
	res.Requests = len(requests)
	return res, nil
}

func (s *insightStore) clear() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	err := os.Remove(s.path)
	if err != nil && os.IsNotExist(err) {
		return nil
	}
	return err
}
PGO

cat > "$TARGET/privacy/admin_api.go" <<'PAPI'
package privacy

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// RegisterAdminRoutes adds the dashboard endpoints to an admin route group.
func RegisterAdminRoutes(routes gin.IRoutes) {
	routes.GET("/privacy/masking/summary", privacySummaryHandler)
	routes.GET("/privacy/masking/events", privacyEventsHandler)
	routes.DELETE("/privacy/masking/events", privacyClearHandler)
}

func privacySummaryHandler(c *gin.Context) {
	days := queryInt(c, "days", 7, 1, 90)
	summary, err := insights.summary(days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": summary})
}

func privacyEventsHandler(c *gin.Context) {
	days := queryInt(c, "days", 7, 1, 90)
	limit := queryInt(c, "limit", 100, 1, 1000)
	events, err := insights.events(days, c.Query("kind"), limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": events})
}

func privacyClearHandler(c *gin.Context) {
	if err := insights.clear(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"cleared": true}})
}

func queryInt(c *gin.Context, key string, fallback, min, max int) int {
	v, err := strconv.Atoi(c.Query(key))
	if err != nil || v <= 0 {
		return fallback
	}
	if v < min {
		return min
	}
	if v > max {
		return max
	}
	return v
}
PAPI

cat > "$TARGET/privacy/middleware.go" <<'PMW'
package privacy

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"strings"

	"github.com/QuantumNous/new-api/common"
	"github.com/QuantumNous/new-api/internal/privacy/redact"
	"github.com/gin-gonic/gin"
)

// Middleware masks every JSON relay request before it reaches the channel
// adapters, and restores placeholders in the response, streaming included.
// It is always on for relay routes: no setting, no database, no frontend.
func Middleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !isRelayPath(c.Request.URL.Path) || strings.EqualFold(c.GetHeader("Upgrade"), "websocket") {
			c.Next()
			return
		}

		meta := MaskEvent{RequestID: nextRequestID(), Path: c.Request.URL.Path}
		meta.UserID = requestUserID(c)

		maskRequestBody(c, &meta)

		original := c.Writer
		rw := redact.NewWriter(original)
		c.Writer = &ginWriter{ResponseWriter: original, rw: rw}
		defer rw.Finish()

		c.Next()
	}
}

func isRelayPath(path string) bool {
	return path == "/v1" || path == "/v1beta" ||
		strings.HasPrefix(path, "/v1/") || strings.HasPrefix(path, "/v1beta/")
}

func requestUserID(c *gin.Context) string {
	for _, key := range []string{"id", "user_id", "userId"} {
		if v, ok := c.Get(key); ok && v != nil {
			return fmt.Sprint(v)
		}
	}
	return ""
}

// maskRequestBody replaces the request body with its masked version. The
// body storage cache is invalidated so new-api's reusable unmarshalling
// reads the masked bytes.
func maskRequestBody(c *gin.Context, meta *MaskEvent) {
	if !strings.Contains(c.ContentType(), "application/json") {
		return
	}
	storage, err := common.GetBodyStorage(c)
	if err != nil {
		return
	}
	body, err := storage.Bytes()
	if err != nil || len(body) == 0 {
		return
	}
	meta.Model = modelFromJSON(body)

	opts := redact.Options{Secrets: true, Personal: true}
	opts.Seen = func(h redact.Hit) {
		e := *meta
		e.Kind = h.Kind
		e.By = h.By
		e.Action = h.Action
		e.Placeholder = h.Placeholder
		e.Head = h.Head
		e.Len = h.Len
		insights.record(e)
	}

	masked, _ := redact.MaskJSON(body, opts)
	if bytes.Equal(masked, body) {
		return
	}

	_ = storage.Close()
	c.Request.Body = io.NopCloser(bytes.NewReader(masked))
	c.Request.ContentLength = int64(len(masked))
	c.Set(common.KeyBodyStorage, nil)
	c.Set(common.KeyRequestBody, nil)
}

func modelFromJSON(body []byte) string {
	var probe struct {
		Model string `json:"model"`
	}
	if json.Unmarshal(body, &probe) != nil {
		return ""
	}
	return probe.Model
}
PMW

cat > "$TARGET/privacy/insights_test.go" <<'PTEST'
package privacy

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestInsightStoreKeepsMetadataOnly(t *testing.T) {
	dir := t.TempDir()
	s := &insightStore{
		path:      filepath.Join(dir, "privacy.jsonl"),
		retention: 30 * 24 * time.Hour,
		maxLines:  100,
	}
	plaintext := "alice" + "@" + "acme" + ".com"
	s.record(MaskEvent{
		RequestID:   "req-1",
		Path:        "/v1/chat/completions",
		Kind:        "EMAIL",
		By:          "rule",
		Placeholder: "{{EMAIL_abcdefgh}}",
		Head:        "a",
		Len:         len(plaintext),
	})

	sum, err := s.summary(7)
	if err != nil {
		t.Fatal(err)
	}
	if sum.Total != 1 || sum.Requests != 1 || sum.ByKind["EMAIL"] != 1 {
		t.Fatalf("unexpected summary: %+v", sum)
	}
	raw, err := os.ReadFile(s.path)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(raw), plaintext) {
		t.Fatalf("insight file contains plaintext: %s", raw)
	}
}
PTEST

# ---------------------------------------------------------- router hook ----
API_ROUTER="$TARGET/router/api-router.go"
if ! grep -q '"github.com/QuantumNous/new-api/privacy"' "$API_ROUTER"; then
    perl -0pi -e 's#(\t"github\.com/QuantumNous/new-api/middleware"\n)#$1\t"github.com/QuantumNous/new-api/privacy"\n#' "$API_ROUTER"
fi
if ! grep -q 'privacy.RegisterAdminRoutes' "$API_ROUTER"; then
    perl -0pi -e 's#(\t\t\tadminRoute\.Use\(middleware\.AdminAuth\(\)\)\n)#$1\t\t\tprivacy.RegisterAdminRoutes(adminRoute)\n#' "$API_ROUTER"
fi
grep -q 'privacy.RegisterAdminRoutes' "$API_ROUTER" || { echo "failed to register privacy admin routes" >&2; exit 1; }

# ------------------------------------------------------------- frontend ----
mkdir -p "$TARGET/web/default/src/features/dashboard/components/privacy"
cat > "$TARGET/web/default/src/features/dashboard/components/privacy/privacy-masking.tsx" <<'PFRONT'
import { useCallback, useEffect, useMemo, useState } from 'react'

import { Button } from '@/components/ui/button'
import { api } from '@/lib/api'

type MaskEvent = {
  id: string
  time: string
  request_id: string
  path: string
  model?: string
  user_id?: string
  kind: string
  by: string
  action?: string
  placeholder: string
  head: string
  len: number
}

type MaskSummary = {
  days: number
  total: number
  requests: number
  by_kind: Record<string, number>
  by_day: Record<string, number>
  by_model: Record<string, number>
}

export function PrivacyMasking() {
  const [days, setDays] = useState(7)
  const [summary, setSummary] = useState<MaskSummary | null>(null)
  const [events, setEvents] = useState<MaskEvent[]>([])
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const [s, e] = await Promise.all([
        api.get<{ success: boolean; data: MaskSummary }>(
          '/api/privacy/masking/summary',
          { params: { days } }
        ),
        api.get<{ success: boolean; data: MaskEvent[] }>(
          '/api/privacy/masking/events',
          { params: { days, limit: 200 } }
        ),
      ])
      setSummary(s.data.data)
      setEvents(e.data.data)
    } catch (err) {
      setError(String(err))
    } finally {
      setLoading(false)
    }
  }, [days])

  useEffect(() => {
    void load()
  }, [load])

  const maxDay = useMemo(
    () => Math.max(1, ...Object.values(summary?.by_day ?? {})),
    [summary]
  )

  const clear = async () => {
    if (!window.confirm('Clear all privacy masking history?')) return
    await api.delete('/api/privacy/masking/events')
    await load()
  }

  return (
    <div className='space-y-4'>
      <div className='flex flex-wrap items-center justify-between gap-2'>
        <div className='flex items-center gap-2'>
          {[7, 14, 30].map((d) => (
            <Button
              key={d}
              size='sm'
              variant={days === d ? 'default' : 'outline'}
              onClick={() => setDays(d)}
            >
              {d}d
            </Button>
          ))}
        </div>
        <div className='flex items-center gap-2'>
          <Button size='sm' variant='outline' onClick={() => void load()}>
            Refresh
          </Button>
          <Button size='sm' variant='outline' onClick={() => void clear()}>
            Clear
          </Button>
        </div>
      </div>

      {error && (
        <div className='rounded-lg border border-red-500/40 bg-red-500/10 p-3 text-sm text-red-500'>
          {error}
        </div>
      )}

      <div className='grid grid-cols-2 gap-3 lg:grid-cols-4'>
        <div className='rounded-lg border p-4'>
          <div className='text-muted-foreground text-xs'>Masked values</div>
          <div className='mt-1 text-2xl font-semibold'>
            {summary?.total ?? '—'}
          </div>
        </div>
        <div className='rounded-lg border p-4'>
          <div className='text-muted-foreground text-xs'>Requests</div>
          <div className='mt-1 text-2xl font-semibold'>
            {summary?.requests ?? '—'}
          </div>
        </div>
        <div className='rounded-lg border p-4'>
          <div className='text-muted-foreground text-xs'>Kinds</div>
          <div className='mt-1 text-2xl font-semibold'>
            {Object.keys(summary?.by_kind ?? {}).length}
          </div>
        </div>
        <div className='rounded-lg border p-4'>
          <div className='text-muted-foreground text-xs'>Window</div>
          <div className='mt-1 text-2xl font-semibold'>{days} days</div>
        </div>
      </div>

      <div className='grid gap-4 lg:grid-cols-2'>
        <div className='rounded-lg border p-4'>
          <h3 className='mb-3 text-sm font-medium'>By kind</h3>
          <div className='space-y-2'>
            {Object.entries(summary?.by_kind ?? {}).length === 0 && (
              <div className='text-muted-foreground text-sm'>No data</div>
            )}
            {Object.entries(summary?.by_kind ?? {})
              .sort((a, b) => b[1] - a[1])
              .map(([kind, count]) => (
                <div key={kind} className='flex items-center gap-3 text-sm'>
                  <span className='w-28 shrink-0'>{kind}</span>
                  <div className='bg-muted h-2 flex-1 rounded'>
                    <div
                      className='bg-primary h-2 rounded'
                      style={{ width: `${Math.min(100, (count / Math.max(1, summary?.total ?? 1)) * 100)}%` }}
                    />
                  </div>
                  <span className='w-10 text-right tabular-nums'>{count}</span>
                </div>
              ))}
          </div>
        </div>

        <div className='rounded-lg border p-4'>
          <h3 className='mb-3 text-sm font-medium'>Daily trend</h3>
          <div className='space-y-2'>
            {Object.entries(summary?.by_day ?? {}).length === 0 && (
              <div className='text-muted-foreground text-sm'>No data</div>
            )}
            {Object.entries(summary?.by_day ?? {})
              .sort((a, b) => a[0].localeCompare(b[0]))
              .map(([day, count]) => (
                <div key={day} className='flex items-center gap-3 text-sm'>
                  <span className='w-24 shrink-0 tabular-nums'>{day}</span>
                  <div className='bg-muted h-2 flex-1 rounded'>
                    <div
                      className='bg-primary h-2 rounded'
                      style={{ width: `${(count / maxDay) * 100}%` }}
                    />
                  </div>
                  <span className='w-10 text-right tabular-nums'>{count}</span>
                </div>
              ))}
          </div>
        </div>
      </div>

      <div className='rounded-lg border'>
        <div className='border-b px-4 py-3 text-sm font-medium'>Recent masked values</div>
        <div className='overflow-x-auto'>
          <table className='w-full text-sm'>
            <thead className='text-muted-foreground border-b text-xs'>
              <tr>
                <th className='px-4 py-2 text-left'>Time</th>
                <th className='px-4 py-2 text-left'>Kind</th>
                <th className='px-4 py-2 text-left'>Placeholder</th>
                <th className='px-4 py-2 text-left'>Head</th>
                <th className='px-4 py-2 text-right'>Len</th>
                <th className='px-4 py-2 text-left'>Route</th>
                <th className='px-4 py-2 text-left'>Model</th>
              </tr>
            </thead>
            <tbody>
              {events.length === 0 && (
                <tr>
                  <td className='text-muted-foreground px-4 py-6 text-center' colSpan={7}>
                    {loading ? 'Loading...' : 'No masked values in this window'}
                  </td>
                </tr>
              )}
              {events.map((e) => (
                <tr key={e.id} className='border-b last:border-0'>
                  <td className='px-4 py-2 tabular-nums'>
                    {new Date(e.time).toLocaleString()}
                  </td>
                  <td className='px-4 py-2'>{e.kind}</td>
                  <td className='px-4 py-2 font-mono text-xs'>{e.placeholder}</td>
                  <td className='px-4 py-2 font-mono text-xs'>{e.head || '—'}</td>
                  <td className='px-4 py-2 text-right tabular-nums'>{e.len}</td>
                  <td className='px-4 py-2 text-xs'>{e.path}</td>
                  <td className='px-4 py-2 text-xs'>{e.model || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
PFRONT

# Dashboard section registration.
REG="$TARGET/web/default/src/features/dashboard/section-registry.tsx"
if ! grep -q "id: 'privacy'" "$REG"; then
    perl -0pi -e "s#(\n\] as const)#\n  {\n    id: 'privacy',\n    titleKey: 'Privacy Masking',\n    adminOnly: true,\n    build: () => null,\n  },\$1#" "$REG"
fi
perl -0pi -e "s#new Set<string>\(\['users'\]\)#new Set<string>(['users', 'privacy'])#" "$REG"

IDX="$TARGET/web/default/src/features/dashboard/index.tsx"
if ! grep -q 'LazyPrivacyMasking' "$IDX"; then
    perl -0pi -e "s#(const LazyFlowCharts = lazy\(\(\) =>\n  import\('\./components/flow/flow-charts'\)\.then\(\(m\) => \(\{\n    default: m\.FlowCharts,\n  \}\)\)\n\))#\$1\nconst LazyPrivacyMasking = lazy(() =>\n  import('./components/privacy/privacy-masking').then((m) => ({\n    default: m.PrivacyMasking,\n  }))\n)\n#" "$IDX"
fi
if ! grep -q "  privacy: {" "$IDX"; then
    perl -0pi -e "s#(  users: \{\n    titleKey: 'User Analytics',\n  \},\n)#\$1  privacy: {\n    titleKey: 'Privacy Masking',\n  },\n#" "$IDX"
fi
perl -0pi -e "s#\(section\) => section !== 'overview' && \(section !== 'users' \|\| isAdmin\)#(section) =>\n          section !== 'overview' &&\n          (isAdmin || (section !== 'users' && section !== 'privacy'))#" "$IDX"
if ! grep -q "activeSection === 'privacy'" "$IDX"; then
    perl -0pi -e "s#(        </div>\n      </SectionPageLayout.Content>)#          {activeSection === 'privacy' && isAdmin && (\n            <FadeIn>\n              <Suspense fallback={<ModelChartsFallback />}>\n                <LazyPrivacyMasking />\n              </Suspense>\n            </FadeIn>\n          )}\n\$1#" "$IDX"
fi

# Minimal i18n keys for the section title.
EN="$TARGET/web/default/src/i18n/locales/en.json"
if ! grep -q '"Privacy Masking"' "$EN"; then
    perl -0pi -e 's#("Previous page": "[^"]*",\n)#$1    "Privacy Masking": "Privacy Masking",\n#' "$EN"
fi
ZH="$TARGET/web/default/src/i18n/locales/zh.json"
if ! grep -q '"Privacy Masking"' "$ZH"; then
    perl -0pi -e 's#("Previous page": "[^"]*",\n)#$1    "Privacy Masking": "隐私脱敏看板",\n#' "$ZH"
fi

for spec in \
    "ja|プライバシーマスキング" \
    "ru|Маскирование конфиденциальных данных" \
    "fr|Masquage de la confidentialité" \
    "vi|Che giấu quyền riêng tư"; do
    LOCALE="${spec%%|*}"
    TEXT="${spec#*|}"
    FILE="$TARGET/web/default/src/i18n/locales/$LOCALE.json"
    if [ -f "$FILE" ] && ! grep -q '"Privacy Masking"' "$FILE"; then
        TEXT="$TEXT" perl -0pi -e 'my $t = $ENV{TEXT}; s#("Previous page": "[^"]*",\n)#$1    "Privacy Masking": "$t",\n#' "$FILE"
    fi
done

echo "Applied privacy-masking dashboard patch"
echo "========================================="
