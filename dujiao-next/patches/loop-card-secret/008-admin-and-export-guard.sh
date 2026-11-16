#!/bin/bash
DESCRIPTION="\
循环卡密（一密多发）第八步: 后台展示 + 导出守卫。
两处都会让循环规格「看起来像售罄」，必须修。

1. frontend/admin/src/views/admin/Products.vue
   库存聚合对循环规格返回 -1（沿用「负数 = 不限」既有约定），但这个页面的
   auto 分支没有处理负数:
   注意这里有个坑: 这两个函数用的是 toSafeInt，而 toSafeInt 的实现是
   Math.max(Math.floor(num), 0) —— 会把 -1 夹成 0。所以「补一个 total < 0
   的分支」是无效的死代码，必须先换成上游为 manual 分支准备的 toSafeStockTotal
   （它特意 if (integer === -1) return -1），-1 才能活着走到判断里。
   若不换，-1 被夹成 0，页面显示「库存 0/0」并配红色售罄徽章。

2. internal/modules/cardsecret/application/export.go
   后台「导出可用卡密」会把导出的行批量改成 used。对循环规格这是灾难:
   那条唯一的卡密一旦变成 used，可用数不再是 1，就不再进入库存探测候选集，
   后台显示 0/0 已售 1、买家端显示售罄 —— 与发货判定顺序那个 bug 表现一致。
   因此导出时把循环卡密排除在外（不可导出）: 取到行就过滤，一条都不会被标已用。
   过滤写成函数内局部闭包: export.go 的顶层函数清单被结构测试逐个钉死。"

set -euo pipefail

T="${1:-}"
[ -n "$T" ] || { echo "usage: $0 <target_dir>" >&2; exit 1; }
[ -d "$T" ] || { echo "target dir not found: $T" >&2; exit 1; }

die() { echo "loop-card-secret/008: $*" >&2; exit 1; }

PRODUCTS_VUE="$T/frontend/admin/src/views/admin/Products.vue"
EXPORT_GO="$T/internal/modules/cardsecret/application/export.go"
[ -f "$PRODUCTS_VUE" ] || die "missing file: $PRODUCTS_VUE"
[ -f "$EXPORT_GO" ] || die "missing file: $EXPORT_GO"

# 说明: 这里全部用「临时块文件 + index/substr 插入」而不是 perl 的 s### 替换。
# 因为插入的 JS/Go 代码里花括号极其密集，用 s{}{} 会把 { 当成分隔符嵌套，
# 把后续整段文本（含中文注释）吞进替换体，直接报 "Unrecognized character"。

# ---------------------------------------------------------------------------
# 1. 后台商品列表: -1 显示为「库存不限」，徽章不再标红
# ---------------------------------------------------------------------------
if ! grep -q 'if (total < 0) {' "$PRODUCTS_VUE"; then
    BLOCK="$(mktemp)"
    cat > "$BLOCK" <<'EOF'
  // -1 = 不限库存（循环卡密规格），沿用 manual 分支的同一约定
  if (total < 0) {
    return t('admin.products.stock.unlimited')
  }
EOF
    # 先把 total 的读取换成保留 -1 的 toSafeStockTotal，再插判断分支
    BLOCK_FILE="$BLOCK" perl -0pi -e '
BEGIN {
	local $/;
	open my $fh, "<", $ENV{BLOCK_FILE} or die "open block: $!";
	$block = <$fh>;
	close $fh;
}
my $anchor = "const formatAutoStockSummary = (product: AdminProduct) => {\n  const total = toSafeInt(product?.auto_stock_total)\n";
my $pos = index($_, $anchor);
die "formatAutoStockSummary anchor not found\n" if $pos < 0;
my $fixed = "const formatAutoStockSummary = (product: AdminProduct) => {\n  const total = toSafeStockTotal(product?.auto_stock_total)\n";
substr($_, $pos, length($anchor)) = $fixed . $block;
' "$PRODUCTS_VUE"
    rm -f "$BLOCK"
fi

if ! grep -q '// 负数 = 不限库存' "$PRODUCTS_VUE"; then
    BLOCK="$(mktemp)"
    cat > "$BLOCK" <<'EOF'
  // 负数 = 不限库存，不能按售罄的红色渲染
  if (available < 0) {
    return 'border-emerald-200 bg-emerald-50 text-emerald-700'
  }
EOF
    # auto_stock_available 这一行在文件里出现两次（formatAutoStockSummary 与
    # autoStockBadgeClass），必须以 autoStockBadgeClass 的位置为起点向后找。
    BLOCK_FILE="$BLOCK" perl -0pi -e '
BEGIN {
	local $/;
	open my $fh, "<", $ENV{BLOCK_FILE} or die "open block: $!";
	$block = <$fh>;
	close $fh;
}
my $start = index($_, "const autoStockBadgeClass = (product: AdminProduct) => {");
die "autoStockBadgeClass not found\n" if $start < 0;
my $anchor = "  const available = toSafeInt(product?.auto_stock_available)\n";
my $pos = index($_, $anchor, $start);
die "available anchor not found after autoStockBadgeClass\n" if $pos < 0;
my $fixed = "  const available = toSafeStockTotal(product?.auto_stock_available)\n";
substr($_, $pos, length($anchor)) = $fixed . $block;
' "$PRODUCTS_VUE"
    rm -f "$BLOCK"
fi

grep -q 'if (total < 0) {' "$PRODUCTS_VUE" || die "auto stock unlimited branch not added"
grep -q 'if (available < 0) {' "$PRODUCTS_VUE" || die "auto stock badge negative branch not added"
grep -q 'toSafeStockTotal(product?.auto_stock_total)' "$PRODUCTS_VUE" || die "auto total must use toSafeStockTotal (toSafeInt clamps -1 to 0)"
grep -q 'toSafeStockTotal(product?.auto_stock_available)' "$PRODUCTS_VUE" || die "auto available must use toSafeStockTotal (toSafeInt clamps -1 to 0)"
[ "$(grep -c 'admin.products.stock.unlimited' "$PRODUCTS_VUE")" -ge 2 ] || die "unlimited label not reused"

# ---------------------------------------------------------------------------
# 2. 导出可用卡密: 排除循环卡密（不导出、不标记已用）
# ---------------------------------------------------------------------------
if ! grep -q 'excludeLoopSecrets := func' "$EXPORT_GO"; then
    BLOCK="$(mktemp)"
    cat > "$BLOCK" <<'EOF'
		// 循环发货卡密不能走导出: 导出会把行改成 used，而循环规格靠
		// 「可用数量恒为 1」才能被识别，一旦被标已用就永久退化成「售罄」。
		// 写成局部闭包 —— export.go 的顶层函数清单被结构测试钉死。
		excludeLoopSecrets := func(rows []cardsecretdomain.Secret) []cardsecretdomain.Secret {
			kept := make([]cardsecretdomain.Secret, 0, len(rows))
			for _, row := range rows {
				if cardsecretdomain.IsLoopSecret(row.Secret) {
					continue
				}
				kept = append(kept, row)
			}
			return kept
		}
EOF
    BLOCK_FILE="$BLOCK" perl -0pi -e '
BEGIN {
	local $/;
	open my $fh, "<", $ENV{BLOCK_FILE} or die "open block: $!";
	$block = <$fh>;
	close $fh;
}
my $anchor = "err = s.transactions.Transaction(func(secretRepo cardsecretcontract.Repository, _ cardsecretcontract.BatchRepository) error {\n";
my $pos = index($_, $anchor);
die "export transaction closure not found\n" if $pos < 0;
substr($_, $pos + length($anchor), 0) = $block;
' "$EXPORT_GO"
    rm -f "$BLOCK"
fi

if ! grep -q 'items = excludeLoopSecrets(items)' "$EXPORT_GO"; then
    BLOCK="$(mktemp)"
    cat > "$BLOCK" <<'EOF'
		// 循环卡密不可导出（见 excludeLoopSecrets 的说明），必须在数量校验之前过滤
		items = excludeLoopSecrets(items)
EOF
    # `if len(items) == 0` 在 ExportCardSecrets 里也有一处，
    # 因此从 ListAvailableByProductBatchForUpdate 的位置向后找。
    BLOCK_FILE="$BLOCK" perl -0pi -e '
BEGIN {
	local $/;
	open my $fh, "<", $ENV{BLOCK_FILE} or die "open block: $!";
	$block = <$fh>;
	close $fh;
}
my $fetch = index($_, "items, err := secretRepo.ListAvailableByProductBatchForUpdate(");
die "export fetch call not found\n" if $fetch < 0;
my $anchor = "\t\tif len(items) == 0 {\n";
my $pos = index($_, $anchor, $fetch);
die "export emptiness check not found after fetch\n" if $pos < 0;
substr($_, $pos, 0) = $block;
' "$EXPORT_GO"
    rm -f "$BLOCK"
fi

grep -q 'excludeLoopSecrets := func' "$EXPORT_GO" || die "excludeLoopSecrets closure not inserted"
grep -q 'items = excludeLoopSecrets(items)' "$EXPORT_GO" || die "excludeLoopSecrets call not inserted"
[ "$(grep -c 'items = excludeLoopSecrets(items)' "$EXPORT_GO")" = "1" ] || die "excludeLoopSecrets called more than once"

command -v gofmt >/dev/null 2>&1 && gofmt -w "$EXPORT_GO"

# ---------------------------------------------------------------------------
# 3. 导出守卫的回归测试
# ---------------------------------------------------------------------------
INTEGRATION_TEST="$T/internal/modules/cardsecret/integrationtest/service_test.go"
[ -f "$INTEGRATION_TEST" ] || die "missing file: $INTEGRATION_TEST"

if ! grep -q 'func TestLoopSecretIsNotExportable(' "$INTEGRATION_TEST"; then
    cat >> "$INTEGRATION_TEST" <<'EOF'

// TestLoopSecretIsNotExportable 锁定: 后台"导出可用卡密"不能把循环卡密带走。
// 导出会把行改成 used；循环规格一旦失去"可用数量恒为 1"，就永久退化成
// 后台显示 0/0 已售 1、买家端售罄。
func TestLoopSecretIsNotExportable(t *testing.T) {
	db := setupCardSecretServiceTestDB(t)
	product := &productdomain.Product{
		CategoryID:      1,
		Slug:            "export-loop-guard",
		TitleJSON:       jsonmap.JSON{"zh-CN": "循环卡密导出守卫"},
		PriceAmount:     money.FromDecimal(decimal.NewFromInt(88)),
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
		PriceAmount: money.FromDecimal(decimal.NewFromInt(88)),
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
	loopSecret := cardsecretdomain.LoopSecretPrefix + "SHARED-CONTENT"
	batch, _, err := svc.CreateCardSecretBatch(CreateCardSecretBatchInput{
		ProductID: product.ID,
		Secrets:   []string{loopSecret},
		BatchNo:   "EXP-LOOP",
		Source:    constants.CardSecretSourceManual,
	})
	if err != nil {
		t.Fatalf("create loop batch failed: %v", err)
	}

	// 循环规格没有可导出内容
	_, err = svc.ExportAvailableCardSecrets(ExportAvailableCardSecretInput{
		ProductID: product.ID,
		SKUID:     sku.ID,
		BatchID:   batch.ID,
		Limit:     1,
		Format:    constants.ExportFormatTXT,
	})
	if err == nil {
		t.Fatal("exporting a loop card secret should be refused")
	}

	// 关键: 无论导出成功与否，卡密必须仍是 available
	rows, _, err := svc.ListCardSecrets(ListCardSecretInput{
		ProductID: product.ID,
		SKUID:     sku.ID,
		BatchID:   batch.ID,
		Page:      1,
		PageSize:  10,
	})
	if err != nil {
		t.Fatalf("list secrets failed: %v", err)
	}
	if len(rows) != 1 {
		t.Fatalf("want 1 loop secret got %d", len(rows))
	}
	if rows[0].Status != cardsecretdomain.StatusAvailable {
		t.Fatalf("loop secret status want available got %s", rows[0].Status)
	}
}
EOF
fi

grep -q 'func TestLoopSecretIsNotExportable(' "$INTEGRATION_TEST" || die "export guard test not appended"
[ "$(grep -c 'func TestLoopSecretIsNotExportable(' "$INTEGRATION_TEST")" = "1" ] || die "export guard test appended more than once"

command -v gofmt >/dev/null 2>&1 && gofmt -w "$INTEGRATION_TEST"

echo "loop-card-secret/008: OK"
