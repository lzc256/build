#!/bin/bash
DESCRIPTION="\
循环卡密（一密多发）第九步: 「普通库存换成循环卡密」的回归测试。
这是最常见的迁移路径，也是本补丁最容易被问到的一点。

运营实际操作: 一个规格原本贴了几百行普通卡密 → 现在想改成一条循环卡密。
    1. 有普通库存时直接导入循环 → 必须被拒绝（规则: 循环与普通不并存）
    2. 把普通卡密在后台全部"删除"（实际是软删除 deleted_at）
    3. 再导入循环 → 必须成功，且该规格可用数量回到 1

之所以能成立: 导入校验用的 CountAvailable 与库存聚合用的
CountStockByProductIDs 都带 deleted_at IS NULL，软删除的行既不算库存、
也不会挡住循环导入。

测试里刻意单独写了一个走生产聚合路径的 realAvailable helper，而不是复用
既有的 countAvailableCardSecrets —— 后者统计时不带 deleted_at 过滤，
在本场景下会得出 available=6 的错误数字（它只在无软删除行的用例里安全）。"

set -euo pipefail

T="${1:-}"
[ -n "$T" ] || { echo "usage: $0 <target_dir>" >&2; exit 1; }
[ -d "$T" ] || { echo "target dir not found: $T" >&2; exit 1; }

die() { echo "loop-card-secret/009: $*" >&2; exit 1; }

INTEGRATION_TEST="$T/internal/modules/cardsecret/integrationtest/service_test.go"
[ -f "$INTEGRATION_TEST" ] || die "missing file: $INTEGRATION_TEST"

if ! grep -q 'func TestPlainStockCanBeReplacedByLoopSecret(' "$INTEGRATION_TEST"; then
    cat >> "$INTEGRATION_TEST" <<'EOF'

// realAvailable 走生产聚合路径（CountStockByProductIDs，带 deleted_at IS NULL），
// 与页面展示的可用数量完全一致。不要换成 countAvailableCardSecrets：
// 那个 helper 统计时不过滤软删除，在有已删除行的场景会报出偏大的数字。
func realAvailable(t *testing.T, db *gorm.DB, productID, skuID uint) int64 {
	t.Helper()
	rows, err := cardsecretgormstore.New(db).CountStockByProductIDs([]uint{productID})
	if err != nil {
		t.Fatalf("CountStockByProductIDs: %v", err)
	}
	for _, row := range rows {
		if row.SKUID == skuID && row.Status == cardsecretdomain.StatusAvailable {
			return row.Total
		}
	}
	return 0
}

// TestPlainStockCanBeReplacedByLoopSecret 锁定运营最常见的迁移路径:
// 原本贴了很多行普通卡密 → 后台全部删除 → 改导入一条循环卡密。
//
// 关键点: 后台"删除"是软删除（deleted_at），而导入校验与库存聚合都带
// deleted_at IS NULL，所以删掉之后既不会挡住循环导入，也不会算进库存。
func TestPlainStockCanBeReplacedByLoopSecret(t *testing.T) {
	db := setupCardSecretServiceTestDB(t)
	product, sku, svc := newLoopSecretTestService(t, db)

	// 1. 先贴 5 行普通卡密
	batch, _, err := svc.CreateCardSecretBatch(CreateCardSecretBatchInput{
		ProductID: product.ID,
		SKUID:     sku.ID,
		Secrets:   []string{"PLAIN-1", "PLAIN-2", "PLAIN-3", "PLAIN-4", "PLAIN-5"},
		BatchNo:   "PLAIN-BATCH",
		Source:    constants.CardSecretSourceManual,
	})
	if err != nil {
		t.Fatalf("import plain secrets failed: %v", err)
	}
	if got := realAvailable(t, db, product.ID, sku.ID); got != 5 {
		t.Fatalf("plain available want 5 got %d", got)
	}

	// 2. 有普通库存时直接导入循环卡密 → 必须被拒绝
	if _, _, err := svc.CreateCardSecretBatch(CreateCardSecretBatchInput{
		ProductID: product.ID,
		SKUID:     sku.ID,
		Secrets:   []string{cardsecretdomain.LoopSecretPrefix + "SHARED"},
		BatchNo:   "LOOP-EARLY",
		Source:    constants.CardSecretSourceManual,
	}); err != cardsecretapp.ErrLoopSecretMixed {
		t.Fatalf("loop import with plain stock want %v got %v", cardsecretapp.ErrLoopSecretMixed, err)
	}

	// 3. 把普通卡密全部删掉（后台删除 = 软删除 deleted_at）
	var rows []cardsecretdomain.Secret
	if err := db.Find(&rows, "product_id = ? AND sku_id = ?", product.ID, sku.ID).Error; err != nil {
		t.Fatalf("load secrets failed: %v", err)
	}
	ids := make([]uint, 0, len(rows))
	for _, row := range rows {
		ids = append(ids, row.ID)
	}
	deleted, err := svc.BatchDeleteCardSecrets(ids, batch.ID, ListCardSecretInput{ProductID: product.ID, SKUID: sku.ID})
	if err != nil {
		t.Fatalf("delete plain secrets failed: %v", err)
	}
	if deleted != int64(len(ids)) {
		t.Fatalf("deleted want %d got %d", len(ids), deleted)
	}
	// 软删除后库存必须归零（说明聚合没有把已删除行算进去）
	if got := realAvailable(t, db, product.ID, sku.ID); got != 0 {
		t.Fatalf("available after delete want 0 got %d", got)
	}

	// 4. 现在导入循环卡密 → 必须成功，且可用数量回到 1
	if _, _, err := svc.CreateCardSecretBatch(CreateCardSecretBatchInput{
		ProductID: product.ID,
		SKUID:     sku.ID,
		Secrets:   []string{cardsecretdomain.LoopSecretPrefix + "SHARED"},
		BatchNo:   "LOOP-AFTER-DELETE",
		Source:    constants.CardSecretSourceManual,
	}); err != nil {
		t.Fatalf("loop import after deleting plain stock should succeed, got %v", err)
	}
	if got := realAvailable(t, db, product.ID, sku.ID); got != 1 {
		t.Fatalf("loop available want 1 got %d", got)
	}
}
EOF
fi

grep -q 'func TestPlainStockCanBeReplacedByLoopSecret(' "$INTEGRATION_TEST" || die "replace-stock test not appended"
[ "$(grep -c 'func TestPlainStockCanBeReplacedByLoopSecret(' "$INTEGRATION_TEST")" = "1" ] || die "replace-stock test appended more than once"
grep -q 'func realAvailable(' "$INTEGRATION_TEST" || die "realAvailable helper not appended"

command -v gofmt >/dev/null 2>&1 && gofmt -w "$INTEGRATION_TEST"

echo "loop-card-secret/009: OK"
