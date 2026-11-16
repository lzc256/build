#!/bin/bash
DESCRIPTION="\
循环卡密（一密多发）第七步: 库存聚合单测。
在 catalog/product/application/application_test.go 追加（不新增文件）:
- loopStockCounterStub: 在既有 stockCounterStub 上增加 FindLoopSecretSKUs，
  同时记录被探测的候选集，用来断言“高库存规格不入候选集”。
- TestApplyAutoStockCountsMarksLoopSKUAsUnlimited:
    循环规格 → 规格级与商品级都是 -1（不限库存），普通规格保持真实库存。
- TestApplyAutoStockCountsSkipsProbeForStockedSKUs:
    候选集只含“可用数量 == 1”的规格；普通高库存规格一条查询都不会触发，
    库存在 1 但确实是循环规格时命中。
- TestApplyAutoStockCountsKeepsPlainSingleStockSKU:
    “恰好剩 1 条”的普通规格不得被误判为循环（探测未命中时保持 1）。
该目录未被任何结构测试固定文件/函数清单，追加安全。"

set -euo pipefail

T="${1:-}"
[ -n "$T" ] || { echo "usage: $0 <target_dir>" >&2; exit 1; }
[ -d "$T" ] || { echo "target dir not found: $T" >&2; exit 1; }

die() { echo "loop-card-secret/007: $*" >&2; exit 1; }

TESTFILE="$T/internal/modules/catalog/product/application/application_test.go"
[ -f "$TESTFILE" ] || die "missing file: $TESTFILE"

if ! grep -q 'loopStockCounterStub' "$TESTFILE"; then
    cat >> "$TESTFILE" <<'EOF'

// loopStockCounterStub 在 stockCounterStub 之上实现循环卡密探测，
// 并记录每次探测收到的候选集，用于验证候选集筛选逻辑。
type loopStockCounterStub struct {
	stockCounterStub
	loop    []cardsecretcontract.LoopSKU
	probes  [][]cardsecretcontract.LoopSKU
	failErr error
}

func (stub *loopStockCounterStub) FindLoopSecretSKUs(pairs []cardsecretcontract.LoopSKU) ([]cardsecretcontract.LoopSKU, error) {
	stub.probes = append(stub.probes, pairs)
	if stub.failErr != nil {
		return nil, stub.failErr
	}
	return stub.loop, nil
}

func TestApplyAutoStockCountsMarksLoopSKUAsUnlimited(t *testing.T) {
	counter := &loopStockCounterStub{
		stockCounterStub: stockCounterStub{counts: []cardsecretcontract.SKUStockCount{
			{ProductID: 40, SKUID: 401, Status: cardsecretdomain.StatusAvailable, Total: 1},
			{ProductID: 40, SKUID: 402, Status: cardsecretdomain.StatusAvailable, Total: 5},
		}},
		loop: []cardsecretcontract.LoopSKU{{ProductID: 40, SKUID: 401}},
	}
	service := NewService(Options{Stock: counter})
	products := []productdomain.Product{{
		ID:              40,
		FulfillmentType: constants.FulfillmentTypeAuto,
		SKUs: []productdomain.ProductSKU{
			{ID: 401, SKUCode: "LOOP", IsActive: true},
			{ID: 402, SKUCode: "NORMAL", IsActive: true},
		},
	}}

	if err := service.ApplyAutoStockCounts(products); err != nil {
		t.Fatalf("ApplyAutoStockCounts returned error: %v", err)
	}
	// 循环规格与商品级都必须是 -1（不限库存）
	if products[0].SKUs[0].AutoStockAvailable != -1 {
		t.Fatalf("loop sku available want -1 got %d", products[0].SKUs[0].AutoStockAvailable)
	}
	if products[0].SKUs[0].AutoStockTotal != -1 {
		t.Fatalf("loop sku total want -1 got %d", products[0].SKUs[0].AutoStockTotal)
	}
	// 商品级若按普通求和会得到 -1+5=4 这种错误的具体数字
	if products[0].AutoStockAvailable != -1 {
		t.Fatalf("product available want -1 got %d", products[0].AutoStockAvailable)
	}
	// 普通规格保持真实库存
	if products[0].SKUs[1].AutoStockAvailable != 5 {
		t.Fatalf("normal sku available want 5 got %d", products[0].SKUs[1].AutoStockAvailable)
	}
}

func TestApplyAutoStockCountsSkipsProbeForStockedSKUs(t *testing.T) {
	counter := &loopStockCounterStub{
		stockCounterStub: stockCounterStub{counts: []cardsecretcontract.SKUStockCount{
			{ProductID: 41, SKUID: 411, Status: cardsecretdomain.StatusAvailable, Total: 100000},
			{ProductID: 41, SKUID: 412, Status: cardsecretdomain.StatusAvailable, Total: 1},
		}},
		loop: nil,
	}
	service := NewService(Options{Stock: counter})
	products := []productdomain.Product{{
		ID:              41,
		FulfillmentType: constants.FulfillmentTypeAuto,
		SKUs: []productdomain.ProductSKU{
			{ID: 411, SKUCode: "BIG", IsActive: true},
			{ID: 412, SKUCode: "ONE", IsActive: true},
		},
	}}

	if err := service.ApplyAutoStockCounts(products); err != nil {
		t.Fatalf("ApplyAutoStockCounts returned error: %v", err)
	}
	// 10 万库存的规格不能进入候选集
	if len(counter.probes) != 1 {
		t.Fatalf("probe count want 1 got %d", len(counter.probes))
	}
	if len(counter.probes[0]) != 1 || counter.probes[0][0].SKUID != 412 {
		t.Fatalf("probe candidates want only sku 412 got %v", counter.probes[0])
	}
	// 探测未命中：恰好剩 1 条的普通规格必须保持真实库存 1
	if products[0].SKUs[1].AutoStockAvailable != 1 {
		t.Fatalf("plain single-stock sku available want 1 got %d", products[0].SKUs[1].AutoStockAvailable)
	}
}

func TestApplyAutoStockCountsSkipsProbeWhenNoCandidate(t *testing.T) {
	counter := &loopStockCounterStub{
		stockCounterStub: stockCounterStub{counts: []cardsecretcontract.SKUStockCount{
			{ProductID: 42, SKUID: 421, Status: cardsecretdomain.StatusAvailable, Total: 7},
		}},
	}
	service := NewService(Options{Stock: counter})
	products := []productdomain.Product{{
		ID:              42,
		FulfillmentType: constants.FulfillmentTypeAuto,
		SKUs:            []productdomain.ProductSKU{{ID: 421, SKUCode: "BIG", IsActive: true}},
	}}

	if err := service.ApplyAutoStockCounts(products); err != nil {
		t.Fatalf("ApplyAutoStockCounts returned error: %v", err)
	}
	if len(counter.probes) != 0 {
		t.Fatalf("no candidate should skip probe, got %d probes", len(counter.probes))
	}
	if products[0].AutoStockAvailable != 7 {
		t.Fatalf("product available want 7 got %d", products[0].AutoStockAvailable)
	}
}

func TestApplyAutoStockCountsDegradesWhenProbeFails(t *testing.T) {
	counter := &loopStockCounterStub{
		stockCounterStub: stockCounterStub{counts: []cardsecretcontract.SKUStockCount{
			{ProductID: 43, SKUID: 431, Status: cardsecretdomain.StatusAvailable, Total: 1},
		}},
		failErr: errors.New("probe failed"),
	}
	service := NewService(Options{Stock: counter})
	products := []productdomain.Product{{
		ID:              43,
		FulfillmentType: constants.FulfillmentTypeAuto,
		SKUs:            []productdomain.ProductSKU{{ID: 431, SKUCode: "ONE", IsActive: true}},
	}}

	// 探测失败只降级为“不识别”，不能让商品列表整体报错
	if err := service.ApplyAutoStockCounts(products); err != nil {
		t.Fatalf("ApplyAutoStockCounts should tolerate probe failure, got %v", err)
	}
	if products[0].SKUs[0].AutoStockAvailable != 1 {
		t.Fatalf("degraded sku available want 1 got %d", products[0].SKUs[0].AutoStockAvailable)
	}
}

// 保证 stub 始终实现 StockCounter，接口签名变化时这里先报错。
var _ StockCounter = (*loopStockCounterStub)(nil)
EOF
fi

grep -q 'loopStockCounterStub' "$TESTFILE" || die "stock test not appended"
[ "$(grep -c 'func TestApplyAutoStockCountsSkipsProbeForStockedSKUs' "$TESTFILE")" = "1" ] || die "stock test appended more than once"

command -v gofmt >/dev/null 2>&1 && gofmt -w "$TESTFILE"

echo "loop-card-secret/007: OK"
