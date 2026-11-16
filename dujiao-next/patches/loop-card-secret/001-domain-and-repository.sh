#!/bin/bash
DESCRIPTION="\
循环卡密（一密多发）第一步: 领域标记 + 仓储查询。
- cardsecret/domain: 新增 __loop__: 前缀常量与 HasPrefix/TrimPrefix 工具函数
  （不动 Secret 结构体，AutoMigrate 不产生任何 DDL）
- cardsecret/contract: 新增 LoopSKU 类型与两个仓储方法
    CountLoopSecrets      统计某规格下的循环卡密数量（导入校验用）
    FindLoopSecretSKUs    在一批 (product_id, sku_id) 中筛出循环规格
- cardsecret/infrastructure/gormstore: 上述两个方法实现
  FindLoopSecretSKUs 用成对的 (product_id, sku_id) 条件，能吃到既有索引
  idx_card_secret_reserve；禁止写成 sku_id IN (...)（会退化为全表扫）。
全部为新增代码，不修改任何既有语句，可与上游并存。"

set -euo pipefail

T="${1:-}"
[ -n "$T" ] || { echo "usage: $0 <target_dir>" >&2; exit 1; }
[ -d "$T" ] || { echo "target dir not found: $T" >&2; exit 1; }

die() { echo "loop-card-secret/001: $*" >&2; exit 1; }

DOMAIN="$T/internal/modules/cardsecret/domain/secret.go"
PORTS="$T/internal/modules/cardsecret/contract/ports.go"
TYPES="$T/internal/modules/cardsecret/contract/types.go"
STORE="$T/internal/modules/cardsecret/infrastructure/gormstore/store.go"

for f in "$DOMAIN" "$PORTS" "$TYPES" "$STORE"; do
    [ -f "$f" ] || die "missing file: $f"
done

# ---------------------------------------------------------------------------
# 1. 领域：前缀常量 + 工具函数
# ---------------------------------------------------------------------------
if ! grep -q 'LoopSecretPrefix' "$DOMAIN"; then
    # 常量块里追加前缀常量
    perl -0pi -e 's{(\tStatusUsed      = "used"\n)}{$1
	// LoopSecretPrefix 标记“循环发货”卡密: 内容以该前缀开头的卡密不会被消耗，
	// 命中后整单重复发放同一内容（交付时剥离前缀）。仅存在于内容中，不涉及表结构。
	LoopSecretPrefix = "__loop__:"
}' "$DOMAIN"

    # 补 strings 依赖
    grep -q '"strings"' "$DOMAIN" || \
        perl -0pi -e 's{\A(package domain\n\nimport \(\n)}{$1\t"strings"\n}' "$DOMAIN"

    cat >> "$DOMAIN" <<'EOF'

// IsLoopSecret 判断卡密内容是否为循环发货卡密。
func IsLoopSecret(secret string) bool {
	return strings.HasPrefix(secret, LoopSecretPrefix)
}

// LoopSecretContent 返回循环卡密交付给买家的内容（剥离标记前缀）。
func LoopSecretContent(secret string) string {
	return strings.TrimPrefix(secret, LoopSecretPrefix)
}
EOF
fi

grep -q 'func IsLoopSecret' "$DOMAIN" || die "IsLoopSecret not inserted"
grep -q 'func LoopSecretContent' "$DOMAIN" || die "LoopSecretContent not inserted"
grep -q '"strings"' "$DOMAIN" || die "strings import missing in domain"

# ---------------------------------------------------------------------------
# 2. 契约：LoopSKU + 两个仓储方法
# ---------------------------------------------------------------------------
if ! grep -q 'type LoopSKU struct' "$TYPES"; then
    cat >> "$TYPES" <<'EOF'

// LoopSKU 标识商品下的一个规格，用于批量探测循环发货规格。
type LoopSKU struct {
	ProductID uint `gorm:"column:product_id"`
	SKUID     uint `gorm:"column:sku_id"`
}
EOF
fi

if ! grep -q 'CountLoopSecrets' "$PORTS"; then
    perl -0pi -e 's{(\tCountStockByProductIDs\(productIDs \[\]uint\) \(\[\]SKUStockCount, error\)\n)}{$1\t// CountLoopSecrets 统计指定商品规格下的循环发货卡密数量。\n\tCountLoopSecrets(productID, skuID uint) (int64, error)\n\t// FindLoopSecretSKUs 在一批商品规格中筛出存在循环发货卡密的项。\n\tFindLoopSecretSKUs(pairs []LoopSKU) ([]LoopSKU, error)\n}' "$PORTS"
fi

grep -q 'CountLoopSecrets(productID, skuID uint)' "$PORTS" || die "CountLoopSecrets not added to ports"
grep -q 'FindLoopSecretSKUs(pairs \[\]LoopSKU)' "$PORTS" || die "FindLoopSecretSKUs not added to ports"

# ---------------------------------------------------------------------------
# 3. 仓储实现
# ---------------------------------------------------------------------------
if ! grep -q 'func (r \*Store) CountLoopSecrets' "$STORE"; then
    cat >> "$STORE" <<'EOF'

// CountLoopSecrets 统计指定商品规格下的循环发货卡密数量。
// 只用于导入校验（写入路径），不参与下单/展示。
func (r *Store) CountLoopSecrets(productID, skuID uint) (int64, error) {
	if productID == 0 {
		return 0, errors.New("invalid product id")
	}
	query := r.db.Model(&cardsecretdomain.Secret{}).
		Where("product_id = ? AND status = ? AND deleted_at IS NULL", productID, cardsecretdomain.StatusAvailable).
		Where("substr(secret, 1, ?) = ?", len(cardsecretdomain.LoopSecretPrefix), cardsecretdomain.LoopSecretPrefix)
	if skuID > 0 {
		query = query.Where("sku_id = ?", skuID)
	}
	var count int64
	if err := query.Count(&count).Error; err != nil {
		return 0, err
	}
	return count, nil
}

// FindLoopSecretSKUs 在一批商品规格中筛出存在循环发货卡密的项。
//
// 调用方只会传入“可用数量很少”的候选规格（循环规格的可用数量恒为 1），
// 因此这条查询永远碰不到高库存规格。条件必须写成成对的
// (product_id, sku_id)，才可以利用既有索引 idx_card_secret_reserve；
// 若改写成 sku_id IN (...)，索引首列 product_id 用不上，会退化为全表扫描。
func (r *Store) FindLoopSecretSKUs(pairs []cardsecretcontract.LoopSKU) ([]cardsecretcontract.LoopSKU, error) {
	if len(pairs) == 0 {
		return nil, nil
	}
	const batchSize = 200
	result := make([]cardsecretcontract.LoopSKU, 0, len(pairs))
	for start := 0; start < len(pairs); start += batchSize {
		end := start + batchSize
		if end > len(pairs) {
			end = len(pairs)
		}
		conds := make([]string, 0, end-start)
		args := make([]any, 0, (end-start)*2)
		for _, pair := range pairs[start:end] {
			conds = append(conds, "(product_id = ? AND sku_id = ?)")
			args = append(args, pair.ProductID, pair.SKUID)
		}
		var rows []cardsecretcontract.LoopSKU
		if err := r.db.Model(&cardsecretdomain.Secret{}).
			Select("product_id, sku_id").
			Where("status = ? AND deleted_at IS NULL", cardsecretdomain.StatusAvailable).
			Where("substr(secret, 1, ?) = ?", len(cardsecretdomain.LoopSecretPrefix), cardsecretdomain.LoopSecretPrefix).
			Where("("+strings.Join(conds, " OR ")+")", args...).
			Group("product_id, sku_id").
			Scan(&rows).Error; err != nil {
			return nil, err
		}
		result = append(result, rows...)
	}
	return result, nil
}
EOF
fi

grep -q 'func (r \*Store) CountLoopSecrets' "$STORE" || die "CountLoopSecrets not implemented"
grep -q 'func (r \*Store) FindLoopSecretSKUs' "$STORE" || die "FindLoopSecretSKUs not implemented"

echo "loop-card-secret/001: OK"
