#!/bin/bash
DESCRIPTION="\
循环卡密（一密多发）第六步: 测试。
- cardsecret/domain/secret_test.go（新文件，该目录 Go 文件预算为 3，当前 2）
    纯单测：前缀识别（含“形似前缀”“前缀在中间”“只有前缀”等反例）、
    内容剥离（普通卡密必须原样返回）、FirstLoopSecret 的确定性。
- cardsecret/integrationtest/service_test.go（追加到既有文件，不新增文件）
    用既有 sqlite 内存库夹具验证导入期不变量:
    1. 循环卡密导入成功且该规格可用数量恒为 1
    2. 同一规格第二条循环卡密被拒（ErrLoopSecretDuplicate）
    3. 循环与普通不得并存（ErrLoopSecretMixed，两个方向各测一次）
    4. 只有前缀没有内容的循环卡密被拒（ErrInvalid）
这些测试直接锁定下单/展示链路依赖的核心不变量。"

set -euo pipefail

T="${1:-}"
[ -n "$T" ] || { echo "usage: $0 <target_dir>" >&2; exit 1; }
[ -d "$T" ] || { echo "target dir not found: $T" >&2; exit 1; }

die() { echo "loop-card-secret/006: $*" >&2; exit 1; }

DOMAIN_DIR="$T/internal/modules/cardsecret/domain"
DOMAIN_TEST="$DOMAIN_DIR/secret_test.go"
INTEGRATION_TEST="$T/internal/modules/cardsecret/integrationtest/service_test.go"

[ -d "$DOMAIN_DIR" ] || die "missing dir: $DOMAIN_DIR"
[ -f "$INTEGRATION_TEST" ] || die "missing file: $INTEGRATION_TEST"

# ---------------------------------------------------------------------------
# 1. 领域单测
# ---------------------------------------------------------------------------
if [ ! -f "$DOMAIN_TEST" ]; then
    cat > "$DOMAIN_TEST" <<'EOF'
package domain

import "testing"

func TestIsLoopSecret(t *testing.T) {
	cases := []struct {
		name   string
		secret string
		want   bool
	}{
		{"循环卡密", LoopSecretPrefix + "CARD-0001", true},
		{"普通卡密", "CARD-0001", false},
		{"形似前缀但不是", "loop:CARD-0001", false},
		{"前缀出现在中间", "X" + LoopSecretPrefix + "CARD-0001", false},
		{"空字符串", "", false},
	}
	for _, tc := range cases {
		if got := IsLoopSecret(tc.secret); got != tc.want {
			t.Fatalf("%s: IsLoopSecret(%q) = %v, want %v", tc.name, tc.secret, got, tc.want)
		}
	}
}

func TestLoopSecretContent(t *testing.T) {
	if got := LoopSecretContent(LoopSecretPrefix + "CARD-0001"); got != "CARD-0001" {
		t.Fatalf("LoopSecretContent() = %q, want %q", got, "CARD-0001")
	}
	// 普通卡密必须原样返回，避免误伤存量数据
	if got := LoopSecretContent("CARD-0001"); got != "CARD-0001" {
		t.Fatalf("LoopSecretContent(plain) = %q, want %q", got, "CARD-0001")
	}
	if got := LoopSecretContent(LoopSecretPrefix); got != "" {
		t.Fatalf("LoopSecretContent(prefix only) = %q, want empty", got)
	}
}

func TestFirstLoopSecret(t *testing.T) {
	if FirstLoopSecret(nil) != nil {
		t.Fatal("FirstLoopSecret(nil) should be nil")
	}
	plain := []Secret{{ID: 1, Secret: "CARD-0001"}, {ID: 2, Secret: "CARD-0002"}}
	if FirstLoopSecret(plain) != nil {
		t.Fatal("FirstLoopSecret should ignore plain secrets")
	}

	// 传参顺序即优先级：调用方按 id 升序取行，因此 id 最小的一条生效
	mixed := []Secret{
		{ID: 1, Secret: "CARD-0001"},
		{ID: 5, Secret: LoopSecretPrefix + "LOOP-A"},
		{ID: 9, Secret: LoopSecretPrefix + "LOOP-B"},
	}
	got := FirstLoopSecret(mixed)
	if got == nil || got.ID != 5 {
		t.Fatalf("FirstLoopSecret() = %v, want id 5", got)
	}
	if LoopSecretContent(got.Secret) != "LOOP-A" {
		t.Fatalf("FirstLoopSecret content = %q, want %q", LoopSecretContent(got.Secret), "LOOP-A")
	}
}
EOF
fi
[ -f "$DOMAIN_TEST" ] || die "domain test not created"

# ---------------------------------------------------------------------------
# 2. 导入期不变量集成测试（追加到既有文件）
# ---------------------------------------------------------------------------
if ! grep -q 'func TestLoopSecretImportInvariants(' "$INTEGRATION_TEST"; then
    cat >> "$INTEGRATION_TEST" <<'EOF'

func newLoopSecretTestService(t *testing.T, db *gorm.DB) (*productdomain.Product, *productdomain.ProductSKU, *cardsecretapp.Service) {
	t.Helper()
	product := &productdomain.Product{
		CategoryID:      1,
		Slug:            "loop-secret-product",
		TitleJSON:       jsonmap.JSON{"zh-CN": "循环发货商品"},
		PriceAmount:     money.FromDecimal(decimal.NewFromInt(20)),
		PurchaseType:    constants.ProductPurchaseMember,
		FulfillmentType: constants.FulfillmentTypeAuto,
		IsActive:        true,
	}
	if err := db.Create(product).Error; err != nil {
		t.Fatalf("create product failed: %v", err)
	}
	sku := &productdomain.ProductSKU{
		ProductID:   product.ID,
		SKUCode:     productdomain.DefaultSKUCode,
		PriceAmount: money.FromDecimal(decimal.NewFromInt(20)),
		IsActive:    true,
	}
	if err := db.Create(sku).Error; err != nil {
		t.Fatalf("create sku failed: %v", err)
	}
	svc := NewCardSecretService(
		cardsecretgormstore.New(db),
		cardsecretgormstore.NewBatch(db),
		productgormstore.NewProductStore(db),
		productgormstore.NewSKUStore(db),
	)
	return product, sku, svc
}

func countAvailableCardSecrets(t *testing.T, db *gorm.DB, productID, skuID uint) int64 {
	t.Helper()
	var total int64
	if err := db.Model(&cardsecretdomain.Secret{}).
		Where("product_id = ? AND sku_id = ? AND status = ?", productID, skuID, cardsecretdomain.StatusAvailable).
		Count(&total).Error; err != nil {
		t.Fatalf("count available card secrets failed: %v", err)
	}
	return total
}

// TestLoopSecretImportInvariants 锁定下单/展示链路依赖的核心不变量：
// 循环规格的可用数量恒为 1，且循环与普通不得并存。
func TestLoopSecretImportInvariants(t *testing.T) {
	db := setupCardSecretServiceTestDB(t)
	product, sku, svc := newLoopSecretTestService(t, db)

	loopSecret := cardsecretdomain.LoopSecretPrefix + "LOOP-CARD-0001"
	if _, created, err := svc.CreateCardSecretBatch(CreateCardSecretBatchInput{
		ProductID: product.ID,
		Secrets:   []string{loopSecret},
		Source:    constants.CardSecretSourceManual,
		AdminID:   1,
	}); err != nil || created != 1 {
		t.Fatalf("create loop card secret want created=1 err=nil got created=%d err=%v", created, err)
	}
	if got := countAvailableCardSecrets(t, db, product.ID, sku.ID); got != 1 {
		t.Fatalf("available count for loop sku want 1 got %d", got)
	}

	// 同一规格第二条循环卡密必须被拒
	if _, _, err := svc.CreateCardSecretBatch(CreateCardSecretBatchInput{
		ProductID: product.ID,
		Secrets:   []string{cardsecretdomain.LoopSecretPrefix + "LOOP-CARD-0002"},
		Source:    constants.CardSecretSourceManual,
		AdminID:   1,
	}); err != cardsecretapp.ErrLoopSecretDuplicate {
		t.Fatalf("second loop card secret want %v got %v", cardsecretapp.ErrLoopSecretDuplicate, err)
	}
	// 一次导入多条循环卡密同样被拒
	if _, _, err := svc.CreateCardSecretBatch(CreateCardSecretBatchInput{
		ProductID: product.ID,
		Secrets:   []string{cardsecretdomain.LoopSecretPrefix + "A", cardsecretdomain.LoopSecretPrefix + "B"},
		Source:    constants.CardSecretSourceManual,
		AdminID:   1,
	}); err != cardsecretapp.ErrLoopSecretDuplicate {
		t.Fatalf("batch of loop card secrets want %v got %v", cardsecretapp.ErrLoopSecretDuplicate, err)
	}
	// 循环规格不允许再导入普通卡密
	if _, _, err := svc.CreateCardSecretBatch(CreateCardSecretBatchInput{
		ProductID: product.ID,
		Secrets:   []string{"PLAIN-0001"},
		Source:    constants.CardSecretSourceManual,
		AdminID:   1,
	}); err != cardsecretapp.ErrLoopSecretMixed {
		t.Fatalf("plain card secret on loop sku want %v got %v", cardsecretapp.ErrLoopSecretMixed, err)
	}
	// 不变量仍然成立
	if got := countAvailableCardSecrets(t, db, product.ID, sku.ID); got != 1 {
		t.Fatalf("available count must stay 1 after rejections got %d", got)
	}
}

// TestLoopSecretRejectsUpgradeFromNormalStock 普通卡密规格不允许改造成循环规格。
func TestLoopSecretRejectsUpgradeFromNormalStock(t *testing.T) {
	db := setupCardSecretServiceTestDB(t)
	product, sku, svc := newLoopSecretTestService(t, db)

	if _, created, err := svc.CreateCardSecretBatch(CreateCardSecretBatchInput{
		ProductID: product.ID,
		Secrets:   []string{"PLAIN-0001", "PLAIN-0002"},
		Source:    constants.CardSecretSourceManual,
		AdminID:   1,
	}); err != nil || created != 2 {
		t.Fatalf("create plain card secrets want created=2 err=nil got created=%d err=%v", created, err)
	}
	if _, _, err := svc.CreateCardSecretBatch(CreateCardSecretBatchInput{
		ProductID: product.ID,
		Secrets:   []string{cardsecretdomain.LoopSecretPrefix + "LOOP-CARD-0001"},
		Source:    constants.CardSecretSourceManual,
		AdminID:   1,
	}); err != cardsecretapp.ErrLoopSecretMixed {
		t.Fatalf("loop card secret on stocked sku want %v got %v", cardsecretapp.ErrLoopSecretMixed, err)
	}
	if got := countAvailableCardSecrets(t, db, product.ID, sku.ID); got != 2 {
		t.Fatalf("plain stock must stay 2 got %d", got)
	}
}

// TestLoopSecretRequiresContent 只有前缀的循环卡密会交付空串，必须被拒。
func TestLoopSecretRequiresContent(t *testing.T) {
	db := setupCardSecretServiceTestDB(t)
	product, sku, svc := newLoopSecretTestService(t, db)

	if _, _, err := svc.CreateCardSecretBatch(CreateCardSecretBatchInput{
		ProductID: product.ID,
		Secrets:   []string{cardsecretdomain.LoopSecretPrefix},
		Source:    constants.CardSecretSourceManual,
		AdminID:   1,
	}); err != cardsecretapp.ErrInvalid {
		t.Fatalf("empty loop content want %v got %v", cardsecretapp.ErrInvalid, err)
	}
	if got := countAvailableCardSecrets(t, db, product.ID, sku.ID); got != 0 {
		t.Fatalf("no card secret should be created got %d", got)
	}
}
EOF
fi

# ---------------------------------------------------------------------------
# 端到端回归: 循环卡密下单 → 发货
#
# 这一条是必须有的。发货侧最早的实现把「是不是循环卡密」判定放在
# 「从可用行补齐」之前，而循环规格下单时根本不占用卡密行，于是判定必然落空，
# 退化成普通分支:
#   1) 交付内容带着 __loop__: 前缀原样发给买家；
#   2) 那条唯一的卡密被 MarkUsed，可用数归 0，第二次下单直接"已售罄"。
# 两个现象同一个根因，只有把「下单 → 发货 → 再下单 → 再发货」串起来才测得到。
# ---------------------------------------------------------------------------
FULFILL_TEST="$T/internal/modules/fulfillment/integrationtest/application/service_test.go"
[ -f "$FULFILL_TEST" ] || die "missing file: $FULFILL_TEST"

if ! grep -q 'func TestLoopSecretDeliversContentWithoutPrefix(' "$FULFILL_TEST"; then
    cat >> "$FULFILL_TEST" <<'EOF'

// newLoopSecretFulfillmentOrder 建一张已支付、只有一个 auto 明细的订单。
func newLoopSecretFulfillmentOrder(t *testing.T, db *gorm.DB, orderNo string, productID, skuID uint, quantity int, now time.Time) *orderdomain.Order {
	t.Helper()
	order := &orderdomain.Order{
		OrderNo:                 orderNo,
		UserID:                  1,
		Status:                  constants.OrderStatusPaid,
		Currency:                "CNY",
		OriginalAmount:          money.FromDecimal(decimal.NewFromInt(int64(quantity) * 10)),
		DiscountAmount:          money.FromDecimal(decimal.Zero),
		PromotionDiscountAmount: money.FromDecimal(decimal.Zero),
		TotalAmount:             money.FromDecimal(decimal.NewFromInt(int64(quantity) * 10)),
		WalletPaidAmount:        money.FromDecimal(decimal.Zero),
		OnlinePaidAmount:        money.FromDecimal(decimal.NewFromInt(int64(quantity) * 10)),
		RefundedAmount:          money.FromDecimal(decimal.Zero),
		CreatedAt:               now,
		UpdatedAt:               now,
	}
	if err := db.Create(order).Error; err != nil {
		t.Fatalf("create order failed: %v", err)
	}
	item := &orderdomain.OrderItem{
		OrderID:         order.ID,
		ProductID:       productID,
		SKUID:           skuID,
		TitleJSON:       jsonmap.JSON{"zh-CN": "循环发货商品"},
		UnitPrice:       money.FromDecimal(decimal.NewFromInt(10)),
		Quantity:        quantity,
		TotalPrice:      money.FromDecimal(decimal.NewFromInt(int64(quantity) * 10)),
		FulfillmentType: constants.FulfillmentTypeAuto,
		CreatedAt:       now,
		UpdatedAt:       now,
	}
	if err := db.Create(item).Error; err != nil {
		t.Fatalf("create order item failed: %v", err)
	}
	return order
}

func TestLoopSecretDeliversContentWithoutPrefix(t *testing.T) {
	db := setupFulfillmentServiceTestDB(t)
	now := time.Now()

	const loopContent = "shared-account@example.com:password"
	secret := &cardsecretdomain.Secret{
		ProductID: 200,
		SKUID:     2001,
		Secret:    cardsecretdomain.LoopSecretPrefix + loopContent,
		Status:    cardsecretdomain.StatusAvailable,
		CreatedAt: now,
		UpdatedAt: now,
	}
	if err := db.Create(secret).Error; err != nil {
		t.Fatalf("create loop secret failed: %v", err)
	}

	svc := New(Options{
		OrderStore:       ordergormstore.New(db, "test-guest-credential-secret-with-32-bytes"),
		FulfillmentStore: fulfillmentgormstore.New(db),
	})

	// 连续多单：每单都必须成功、内容干净，且卡密不能被消耗。
	// 数量 1 与 3 都要覆盖 —— 判定顺序写错时两者的表现不同：
	//   数量 1 → 不报错，但 payload 带前缀 + 卡密被标 used（"售罄"）；
	//   数量 3 → 直接报"库存不足"。
	round := 0
	for _, quantity := range []int{1, 3, 1} {
		round++
		order := newLoopSecretFulfillmentOrder(t, db, fmt.Sprintf("FULFILL-LOOP-%d", round), 200, 2001, quantity, now)
		result, err := svc.CreateAuto(order.ID)
		if err != nil {
			t.Fatalf("round %d (quantity %d): create auto fulfillment failed: %v", round, quantity, err)
		}
		// 交付内容 = 裸内容重复 quantity 次，绝不能带标记前缀
		wantLines := make([]string, 0, quantity)
		for i := 0; i < quantity; i++ {
			wantLines = append(wantLines, loopContent)
		}
		want := strings.Join(wantLines, "\n")
		if result.Payload != want {
			t.Fatalf("round %d (quantity %d): payload want %q got %q", round, quantity, want, result.Payload)
		}
		if strings.Contains(result.Payload, cardsecretdomain.LoopSecretPrefix) {
			t.Fatalf("round %d (quantity %d): payload must not contain loop prefix, got %q", round, quantity, result.Payload)
		}
	}

	// 发了两单之后那条卡密必须还是 available，否则就是又被 MarkUsed 了
	var after cardsecretdomain.Secret
	if err := db.First(&after, secret.ID).Error; err != nil {
		t.Fatalf("query loop secret failed: %v", err)
	}
	if after.Status != cardsecretdomain.StatusAvailable {
		t.Fatalf("loop secret status want available got %s", after.Status)
	}
	if after.OrderID != nil {
		t.Fatalf("loop secret must not be bound to an order, got order %d", *after.OrderID)
	}
}

func TestLoopSecretFailsClearlyWhenContentMissing(t *testing.T) {
	db := setupFulfillmentServiceTestDB(t)
	now := time.Now()

	secret := &cardsecretdomain.Secret{
		ProductID: 201,
		SKUID:     2011,
		Secret:    cardsecretdomain.LoopSecretPrefix,
		Status:    cardsecretdomain.StatusAvailable,
		CreatedAt: now,
		UpdatedAt: now,
	}
	if err := db.Create(secret).Error; err != nil {
		t.Fatalf("create loop secret failed: %v", err)
	}
	svc := New(Options{
		OrderStore:       ordergormstore.New(db, "test-guest-credential-secret-with-32-bytes"),
		FulfillmentStore: fulfillmentgormstore.New(db),
	})
	// 只有前缀没有内容（绕过导入校验直接写库）：交付空内容比报错更糟，
	// 但也不能因此把卡密标成已用。这里锁定"内容为空时交付空行而不是前缀"。
	order := newLoopSecretFulfillmentOrder(t, db, "FULFILL-LOOP-EMPTY", 201, 2011, 2, now)
	result, err := svc.CreateAuto(order.ID)
	if err != nil {
		t.Fatalf("create auto fulfillment failed: %v", err)
	}
	if result.Payload != "\n" {
		t.Fatalf("empty loop content payload want two empty lines got %q", result.Payload)
	}
}

func TestNormalSKUStillRequiresEnoughStock(t *testing.T) {
	db := setupFulfillmentServiceTestDB(t)
	now := time.Now()

	// 普通规格只有 1 条，买 3 件：必须和上游一样报库存不足，不能被循环逻辑影响
	secret := &cardsecretdomain.Secret{
		ProductID: 202,
		SKUID:     2021,
		Secret:    "PLAIN-CARD-ONLY-ONE",
		Status:    cardsecretdomain.StatusAvailable,
		CreatedAt: now,
		UpdatedAt: now,
	}
	if err := db.Create(secret).Error; err != nil {
		t.Fatalf("create secret failed: %v", err)
	}
	svc := New(Options{
		OrderStore:       ordergormstore.New(db, "test-guest-credential-secret-with-32-bytes"),
		FulfillmentStore: fulfillmentgormstore.New(db),
	})
	order := newLoopSecretFulfillmentOrder(t, db, "FULFILL-PLAIN-SHORT", 202, 2021, 3, now)
	if _, err := svc.CreateAuto(order.ID); err == nil {
		t.Fatal("plain sku with insufficient stock should fail")
	}

	var after cardsecretdomain.Secret
	if err := db.First(&after, secret.ID).Error; err != nil {
		t.Fatalf("query secret failed: %v", err)
	}
	if after.Status != cardsecretdomain.StatusAvailable {
		t.Fatalf("secret status want available got %s", after.Status)
	}
}
EOF
fi

grep -q 'func TestLoopSecretDeliversContentWithoutPrefix(' "$FULFILL_TEST" || die "fulfillment loop test not appended"
[ "$(grep -c 'func TestLoopSecretDeliversContentWithoutPrefix(' "$FULFILL_TEST")" = "1" ] || die "fulfillment loop test appended more than once"

grep -q 'func TestLoopSecretImportInvariants(' "$INTEGRATION_TEST" || die "integration test not appended"
[ "$(grep -c 'func TestLoopSecretImportInvariants(' "$INTEGRATION_TEST")" = "1" ] || die "integration test appended more than once"

command -v gofmt >/dev/null 2>&1 && gofmt -w "$DOMAIN_TEST" "$INTEGRATION_TEST" "$FULFILL_TEST"

echo "loop-card-secret/006: OK"
