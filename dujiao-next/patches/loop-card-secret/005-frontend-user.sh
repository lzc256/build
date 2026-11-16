#!/bin/bash
DESCRIPTION="\
循环卡密（一密多发）第五步: 用户端把 auto 库存的 -1 当作“不限库存”。
后端已把循环发货规格的 auto_stock_available 置为 -1，这里沿用仓库已有的
upstream_stock == -1 → 不限购 约定，让 auto 库存保持同一语义：
- stores/cart.ts          三处 normalizeOptionalStockNumber(..., true) 保留 -1
- useProductDetail.ts / ProductQuickBuy.vue / utils/cartStock.ts
                          改用 normalizeManualStockTotal，避免把 -1 截断成 0
                          （0 会被判成售罄）
- useCart.ts / useCheckout.ts
                          auto 分支遇到负数直接返回 null（不限购），
                          与紧邻的 upstream 分支写法完全对齐
utils/publicStock.ts 已有 autoStock < 0 → null，无需改动。
后台 admin 端零改动。"

set -euo pipefail

T="${1:-}"
[ -n "$T" ] || { echo "usage: $0 <target_dir>" >&2; exit 1; }
[ -d "$T" ] || { echo "target dir not found: $T" >&2; exit 1; }

die() { echo "loop-card-secret/005: $*" >&2; exit 1; }

WEB="$T/frontend/user/src"
CART="$WEB/stores/cart.ts"
DETAIL="$WEB/composables/useProductDetail.ts"
QUICK="$WEB/components/ProductQuickBuy.vue"
CARTSTOCK="$WEB/utils/cartStock.ts"
USECART="$WEB/composables/useCart.ts"
USECHECKOUT="$WEB/composables/useCheckout.ts"

for f in "$CART" "$DETAIL" "$QUICK" "$CARTSTOCK" "$USECART" "$USECHECKOUT"; do
    [ -f "$f" ] || die "missing file: $f"
done

# ---------------------------------------------------------------------------
# 1. stores/cart.ts:保留 -1（与 skuManualStockTotal / skuUpstreamStock 一致）
# ---------------------------------------------------------------------------
perl -0pi -e 's#normalizeOptionalStockNumber\(row\.skuAutoStockAvailable \?\? row\.sku_auto_stock_available\)#normalizeOptionalStockNumber(row.skuAutoStockAvailable ?? row.sku_auto_stock_available, true)#' "$CART"
perl -0pi -e 's#normalizeOptionalStockNumber\(item\.skuAutoStockAvailable\)#normalizeOptionalStockNumber(item.skuAutoStockAvailable, true)#' "$CART"
perl -0pi -e 's#normalizeOptionalStockNumber\(target\.skuAutoStockAvailable\)#normalizeOptionalStockNumber(target.skuAutoStockAvailable, true)#' "$CART"

[ "$(grep -c 'skuAutoStockAvailable, true\|sku_auto_stock_available, true' "$CART")" = "3" ] \
    || die "stores/cart.ts: expected 3 allowUnlimited sites"

# ---------------------------------------------------------------------------
# 2. 源头保留 -1：normalizeStockNumber -> normalizeManualStockTotal
# ---------------------------------------------------------------------------
perl -0pi -e 's#skuAutoStockAvailable: normalizeStockNumber\(sku\?\.auto_stock_available\)#skuAutoStockAvailable: normalizeManualStockTotal(sku?.auto_stock_available)#g' "$DETAIL" "$QUICK"
perl -0pi -e 's#const autoStockAvailable = normalizeStockNumber\(matchedSku\?\.auto_stock_available\)#const autoStockAvailable = normalizeManualStockTotal(matchedSku?.auto_stock_available)#' "$CARTSTOCK"

grep -q 'skuAutoStockAvailable: normalizeManualStockTotal(sku?.auto_stock_available)' "$DETAIL" \
    || die "useProductDetail.ts not updated"
[ "$(grep -c 'skuAutoStockAvailable: normalizeManualStockTotal(sku?.auto_stock_available)' "$QUICK")" = "2" ] \
    || die "ProductQuickBuy.vue: expected 2 sites"
grep -q 'const autoStockAvailable = normalizeManualStockTotal(matchedSku?.auto_stock_available)' "$CARTSTOCK" \
    || die "utils/cartStock.ts not updated"

# ---------------------------------------------------------------------------
# 3. 消费端：auto 分支遇到负数视为不限库存
# ---------------------------------------------------------------------------
MARKER='// 循环发货规格：负数表示不限库存'
for f in "$USECART" "$USECHECKOUT"; do
    grep -q "$MARKER" "$f" && continue
    perl -0pi -e 's#    if \(item\.fulfillmentType === .auto.\) \{\n      return normalizeStockNumber\(item\.skuAutoStockAvailable\)\n    \}#    if (item.fulfillmentType === \x27auto\x27) {\n      const autoStock = Number(item.skuAutoStockAvailable ?? 0)\n      if (autoStock < 0) return null // 循环发货规格：负数表示不限库存\n      return normalizeStockNumber(autoStock)\n    }#' "$f"
done

# 兼容早期版本脚本写坏的片段（本轮自修复，保证幂等）
perl -0pi -e 's#fulfillmentType \x27auto\x27\) \{#fulfillmentType === \x27auto\x27) {#g' "$USECART" "$USECHECKOUT"

[ "$(grep -c 'if (autoStock < 0) return null' "$USECART")" = "1" ] || die "useCart.ts auto branch not updated"
[ "$(grep -c 'if (autoStock < 0) return null' "$USECHECKOUT")" = "1" ] || die "useCheckout.ts auto branch not updated"

echo "loop-card-secret/005: OK"
