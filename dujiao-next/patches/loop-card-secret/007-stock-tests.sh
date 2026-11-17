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
该目录未被任何结构测试固定文件/函数清单，追加安全。
另外在 dashboard/infrastructure/gormstore/inventory_test.go 追加:
- TestGetInventoryAlertItemsSkipsLoopSecretSKUs:
    循环规格可用数恒为 1（< 阈值），若不跳过会稳定误报"低库存"。
    这条路径此前完全没有测试，而 004 的探测实现依赖跨模块复用
    cardsecret 的 FindLoopSecretSKUs，必须钉住。"

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

# ---------------------------------------------------------------------------
# 2. dashboard: 低库存预警必须跳过循环规格
#
# 这条路径在补丁之前完全没有测试。循环规格的可用数量恒为 1，低于任何默认
# 阈值，若不跳过会稳定误报"低库存"，运营每天都会看到一条假预警。
# 005（此处为 004）的探测改成复用 cardsecret 的 FindLoopSecretSKUs 之后，
# 更需要一条行为层面的锁。
# ---------------------------------------------------------------------------
DASH_TEST="$T/internal/modules/dashboard/infrastructure/gormstore/inventory_test.go"
[ -f "$DASH_TEST" ] || die "missing file: $DASH_TEST"

if ! grep -q 'func TestGetInventoryAlertItemsSkipsLoopSecretSKUs(' "$DASH_TEST"; then
    cat >> "$DASH_TEST" <<'EOF'

// TestGetInventoryAlertItemsSkipsLoopSecretSKUs 循环发货规格不得进入低库存预警。
//
// 循环规格的可用数量恒为 1（见 cardsecret 导入校验），低于任何有意义的阈值，
// 若不跳过就会稳定误报"低库存"——而且是永远修不掉的那种，因为库存不会变多。
func TestGetInventoryAlertItemsSkipsLoopSecretSKUs(t *testing.T) {
	repo, db := setupDashboardRepositoryTest(t)
	if err := db.AutoMigrate(&cardsecretdomain.Secret{}); err != nil {
		t.Fatalf("migrate card secret failed: %v", err)
	}

	category := createDashboardCategory(t, db, "dashboard-loop-alert")
	loopProduct := &productdomain.Product{
		CategoryID:      category.ID,
		Slug:            "dashboard-loop-alert",
		TitleJSON:       jsonmap.JSON{"zh-CN": "循环发货商品"},
		PriceAmount:     money.FromDecimal(decimal.NewFromInt(99)),
		PurchaseType:    constants.ProductPurchaseMember,
		FulfillmentType: constants.FulfillmentTypeAuto,
		IsActive:        true,
	}
	if err := db.Create(loopProduct).Error; err != nil {
		t.Fatalf("create loop product failed: %v", err)
	}
	loopSKU := &productdomain.ProductSKU{
		ProductID:   loopProduct.ID,
		SKUCode:     "LOOP-SKU",
		PriceAmount: money.FromDecimal(decimal.NewFromInt(99)),
		IsActive:    true,
		SortOrder:   0,
	}
	if err := db.Create(loopSKU).Error; err != nil {
		t.Fatalf("create loop sku failed: %v", err)
	}
	if err := db.Create(&cardsecretdomain.Secret{
		ProductID: loopProduct.ID,
		SKUID:     loopSKU.ID,
		Secret:    cardsecretdomain.LoopSecretPrefix + "DELIVERED-EVERY-TIME",
		Status:    cardsecretdomain.StatusAvailable,
	}).Error; err != nil {
		t.Fatalf("create loop card secret failed: %v", err)
	}

	// 一个真实的低库存普通规格，用来确认预警本身没有被整体关掉
	plainProduct := &productdomain.Product{
		CategoryID:      category.ID,
		Slug:            "dashboard-plain-low-stock",
		TitleJSON:       jsonmap.JSON{"zh-CN": "普通低库存商品"},
		PriceAmount:     money.FromDecimal(decimal.NewFromInt(99)),
		PurchaseType:    constants.ProductPurchaseMember,
		FulfillmentType: constants.FulfillmentTypeAuto,
		IsActive:        true,
	}
	if err := db.Create(plainProduct).Error; err != nil {
		t.Fatalf("create plain product failed: %v", err)
	}
	plainSKU := &productdomain.ProductSKU{
		ProductID:   plainProduct.ID,
		SKUCode:     "PLAIN-SKU",
		PriceAmount: money.FromDecimal(decimal.NewFromInt(99)),
		IsActive:    true,
		SortOrder:   0,
	}
	if err := db.Create(plainSKU).Error; err != nil {
		t.Fatalf("create plain sku failed: %v", err)
	}
	for idx := 0; idx < 2; idx++ {
		if err := db.Create(&cardsecretdomain.Secret{
			ProductID: plainProduct.ID,
			SKUID:     plainSKU.ID,
			Secret:    fmt.Sprintf("PLAIN-%d", idx),
			Status:    cardsecretdomain.StatusAvailable,
		}).Error; err != nil {
			t.Fatalf("create plain card secret failed: %v", err)
		}
	}

	rows, err := repo.GetInventoryAlertItems(5)
	if err != nil {
		t.Fatalf("get inventory alert items failed: %v", err)
	}
	for _, row := range rows {
		if row.ProductID == loopProduct.ID {
			t.Fatalf("loop-secret product must not be reported as low stock, got %+v", row)
		}
	}
	// 普通低库存商品必须照常报警，确认跳过逻辑没有误伤
	foundPlain := false
	for _, row := range rows {
		if row.ProductID == plainProduct.ID {
			foundPlain = true
			if row.AvailableStock != 2 {
				t.Fatalf("plain alert available stock want 2 got %d", row.AvailableStock)
			}
		}
	}
	if !foundPlain {
		t.Fatalf("plain low-stock product should still be alerted, rows=%+v", rows)
	}
}

// TestGetStockStatsSkipsLoopSecretSKUs 商品级/规格级库存统计同样不把循环规格算成低库存。
func TestGetStockStatsSkipsLoopSecretSKUs(t *testing.T) {
	repo, db := setupDashboardRepositoryTest(t)
	if err := db.AutoMigrate(&cardsecretdomain.Secret{}); err != nil {
		t.Fatalf("migrate card secret failed: %v", err)
	}

	category := createDashboardCategory(t, db, "dashboard-loop-stats")
	product := &productdomain.Product{
		CategoryID:      category.ID,
		Slug:            "dashboard-loop-stats",
		TitleJSON:       jsonmap.JSON{"zh-CN": "循环发货商品"},
		PriceAmount:     money.FromDecimal(decimal.NewFromInt(99)),
		PurchaseType:    constants.ProductPurchaseMember,
		FulfillmentType: constants.FulfillmentTypeAuto,
		IsActive:        true,
	}
	if err := db.Create(product).Error; err != nil {
		t.Fatalf("create product failed: %v", err)
	}
	sku := &productdomain.ProductSKU{
		ProductID:   product.ID,
		SKUCode:     "LOOP-SKU",
		PriceAmount: money.FromDecimal(decimal.NewFromInt(99)),
		IsActive:    true,
		SortOrder:   0,
	}
	if err := db.Create(sku).Error; err != nil {
		t.Fatalf("create sku failed: %v", err)
	}
	if err := db.Create(&cardsecretdomain.Secret{
		ProductID: product.ID,
		SKUID:     sku.ID,
		Secret:    cardsecretdomain.LoopSecretPrefix + "SHARED",
		Status:    cardsecretdomain.StatusAvailable,
	}).Error; err != nil {
		t.Fatalf("create loop card secret failed: %v", err)
	}

	stats, err := repo.GetStockStats(5)
	if err != nil {
		t.Fatalf("get stock stats failed: %v", err)
	}
	if stats.LowStockSKUs != 0 {
		t.Fatalf("loop sku must not count as low stock, got %d", stats.LowStockSKUs)
	}
	if stats.LowStockProducts != 0 {
		t.Fatalf("loop product must not count as low stock product, got %d", stats.LowStockProducts)
	}
	if stats.OutOfStockSKUs != 0 {
		t.Fatalf("loop sku must not count as out of stock, got %d", stats.OutOfStockSKUs)
	}
}
EOF
fi

grep -q 'func TestGetInventoryAlertItemsSkipsLoopSecretSKUs(' "$DASH_TEST" || die "dashboard loop alert test not appended"
grep -q 'func TestGetStockStatsSkipsLoopSecretSKUs(' "$DASH_TEST" || die "dashboard loop stats test not appended"

command -v gofmt >/dev/null 2>&1 && gofmt -w "$TESTFILE" "$DASH_TEST"

echo "loop-card-secret/007: OK"
