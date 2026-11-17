#!/bin/bash
DESCRIPTION="\
循环卡密（一密多发）第四步: 库存展示与后台预警。
- catalog/product/application/stock.go
    用**可选接口断言**接上 FindLoopSecretSKUs，不改动既有 StockCounter 窄接口
    （否则会破坏上游及测试里的 stub）。
    候选集只取“可用数量 == 1”的规格：循环规格的可用数量恒为 1（由导入校验保证），
    因此 10 万库存的规格永远不会进入候选集，一条查询都不会发。
    命中后把规格级库存置为 -1（复用既有“负数 = 不限库存”约定），
    商品级只要有一个循环规格也置 -1。
- catalog/product/transport/http/public_stock.go
    上游这里会把各规格 AutoStockAvailable 直接相加；若一个商品同时有
    循环规格(-1) 与普通规格(5)，会算出 4（正好显示低库存）。
    改为任一启用规格为负数即整商品“不限”。
- dashboard/infrastructure/gormstore/inventory.go
    两条统计 SQL 完全不改，只在 Go 侧跳过循环规格的预警，
    并抑制含循环规格商品的商品级/兜底预警。
所有新增查询都带成对的 (product_id, sku_id) 条件，能吃到既有索引。"

set -euo pipefail

T="${1:-}"
[ -n "$T" ] || { echo "usage: $0 <target_dir>" >&2; exit 1; }
[ -d "$T" ] || { echo "target dir not found: $T" >&2; exit 1; }

die() { echo "loop-card-secret/004: $*" >&2; exit 1; }

STOCK="$T/internal/modules/catalog/product/application/stock.go"
PUBLIC="$T/internal/modules/catalog/product/transport/http/public_stock.go"
INVENTORY="$T/internal/modules/dashboard/infrastructure/gormstore/inventory.go"

for f in "$STOCK" "$PUBLIC" "$INVENTORY"; do
    [ -f "$f" ] || die "missing file: $f"
done

# 说明: 本脚本的 perl 替换统一用 '#' 作分隔符（替换文本里含 { } != 等字符）。

# ---------------------------------------------------------------------------
# 1. stock.go: 候选集探测 + 置 -1
# ---------------------------------------------------------------------------
if ! grep -q 'resolveLoopSecretSKUs' "$STOCK"; then
    # imports
    grep -q '"sort"' "$STOCK" || \
        perl -0pi -e 's#(\t"strings"\n)#$1\t"sort"\n#' "$STOCK"
    grep -q 'cardsecret/contract"' "$STOCK" || \
        perl -0pi -e 's#(\tcardsecretdomain "github\.com/dujiao-next/internal/modules/cardsecret/domain"\n)#\tcardsecretcontract "github.com/dujiao-next/internal/modules/cardsecret/contract"\n$1#' "$STOCK"

    # 探测：放在按商品循环之前
    perl -0pi -e 's#\tfor i := range products \{\n\t\tif products\[i\]\.FulfillmentType != constants\.FulfillmentTypeAuto \{\n#\t// 循环发货规格的可用数量恒为 1，只探测这批候选，高库存规格永不被探测。\n\tloopSKUs := resolveLoopSecretSKUs(s.stock, stockMap)\n\n$1\tfor i := range products {\n\t\tif products[i].FulfillmentType != constants.FulfillmentTypeAuto {\n#' "$STOCK"

    # 商品级：任一规格循环 → -1
    perl -0pi -e 's#\t\tproducts\[i\]\.AutoStockAvailable = pAvailable\n\t\tproducts\[i\]\.AutoStockTotal = pAvailable \+ pLocked\n\t\tproducts\[i\]\.AutoStockLocked = pLocked\n\t\tproducts\[i\]\.AutoStockSold = pUsed\n#\t\tproducts[i].AutoStockAvailable = pAvailable\n\t\tproducts[i].AutoStockTotal = pAvailable + pLocked\n\t\tproducts[i].AutoStockLocked = pLocked\n\t\tproducts[i].AutoStockSold = pUsed\n\t\tfor skuID := range pMap {\n\t\t\tif _, isLoop := loopSKUs[cardsecretcontract.LoopSKU{ProductID: products[i].ID, SKUID: skuID}]; isLoop {\n\t\t\t\tproducts[i].AutoStockAvailable = -1\n\t\t\t\tproducts[i].AutoStockTotal = -1\n\t\t\t\tbreak\n\t\t\t}\n\t\t}\n#' "$STOCK"

    # 规格级：循环规格 → -1
    perl -0pi -e 's#\t\t\tproducts\[i\]\.SKUs\[j\]\.AutoStockAvailable = available\n\t\t\tproducts\[i\]\.SKUs\[j\]\.AutoStockTotal = available \+ locked\n\t\t\tproducts\[i\]\.SKUs\[j\]\.AutoStockLocked = locked\n\t\t\tproducts\[i\]\.SKUs\[j\]\.AutoStockSold = used\n#\t\t\tif _, isLoop := loopSKUs[cardsecretcontract.LoopSKU{ProductID: products[i].ID, SKUID: skuID}]; isLoop {\n\t\t\t\t// -1 表示不限库存（与人工不限库存沿用同一约定）\n\t\t\t\tproducts[i].SKUs[j].AutoStockAvailable = -1\n\t\t\t\tproducts[i].SKUs[j].AutoStockTotal = -1\n\t\t\t\tproducts[i].SKUs[j].AutoStockLocked = 0\n\t\t\t\tproducts[i].SKUs[j].AutoStockSold = 0\n\t\t\t\tcontinue\n\t\t\t}\n\t\t\tproducts[i].SKUs[j].AutoStockAvailable = available\n\t\t\tproducts[i].SKUs[j].AutoStockTotal = available + locked\n\t\t\tproducts[i].SKUs[j].AutoStockLocked = locked\n\t\t\tproducts[i].SKUs[j].AutoStockSold = used\n#' "$STOCK"

    cat >> "$STOCK" <<'EOF'

// loopSecretProbeLimit 限制单次请求探测的候选规格数量，避免异常数据把请求拖慢。
const loopSecretProbeLimit = 1000

// loopSecretFinder 是卡密库存端口的可选能力：底层仓储实现时才启用循环卡密识别。
// 用可选接口而不是扩展 StockCounter，可以不改动上游接口与其测试 stub。
type loopSecretFinder interface {
	FindLoopSecretSKUs(pairs []cardsecretcontract.LoopSKU) ([]cardsecretcontract.LoopSKU, error)
}

// resolveLoopSecretSKUs 在“可用数量为 1”的候选规格中探测循环发货规格。
//
// 同一套逻辑还有一份实现在 dashboard（inventory.go 的 detectLoopSecretSKUs），
// 探测 SQL 又与 cardsecret 的 FindLoopSecretSKUs 重复。这是刻意的模块边界取舍：
// 改候选条件（available == 1）、批大小或上限时三处必须同步。
//
// 候选集恒小：循环规格的可用数量必然是 1（导入校验保证每规格最多一条循环卡密，
// 且不与普通卡密并存），因此普通的高库存规格永远不参与探测，成本与库存量无关。
// 探测失败时静默降级为“不识别”，不影响商品展示。
func resolveLoopSecretSKUs(counter StockCounter, stockMap map[uint]map[uint]map[string]int64) map[cardsecretcontract.LoopSKU]struct{} {
	finder, ok := counter.(loopSecretFinder)
	if !ok {
		return nil
	}
	candidates := make([]cardsecretcontract.LoopSKU, 0)
	for productID, skuMap := range stockMap {
		for skuID, statusMap := range skuMap {
			if skuID == 0 || statusMap[cardsecretdomain.StatusAvailable] != 1 {
				continue
			}
			candidates = append(candidates, cardsecretcontract.LoopSKU{ProductID: productID, SKUID: skuID})
		}
	}
	if len(candidates) == 0 {
		return nil
	}
	sort.Slice(candidates, func(i, j int) bool {
		if candidates[i].ProductID != candidates[j].ProductID {
			return candidates[i].ProductID < candidates[j].ProductID
		}
		return candidates[i].SKUID < candidates[j].SKUID
	})
	if len(candidates) > loopSecretProbeLimit {
		candidates = candidates[:loopSecretProbeLimit]
	}
	found, err := finder.FindLoopSecretSKUs(candidates)
	if err != nil {
		return nil
	}
	result := make(map[cardsecretcontract.LoopSKU]struct{}, len(found))
	for _, item := range found {
		result[item] = struct{}{}
	}
	return result
}
EOF
fi

grep -q 'resolveLoopSecretSKUs' "$STOCK" || die "stock.go probe not inserted"
grep -q '"sort"' "$STOCK" || die "sort import missing in stock.go"
grep -q 'cardsecret/contract"' "$STOCK" || die "contract import missing in stock.go"

# ---------------------------------------------------------------------------
# 2. public_stock.go: 商品级汇总不再直接把 -1 相加
# ---------------------------------------------------------------------------
if ! grep -q 'hasLoopSKU' "$PUBLIC"; then
    perl -0pi -e 's#\tautoAvailable := int64\(0\)\n\tautoTotal := int64\(0\)\n\tautoLocked := int64\(0\)\n\tautoSold := int64\(0\)\n\tfor _, sku := range product\.SKUs \{\n\t\tif !sku\.IsActive \{\n\t\t\tcontinue\n\t\t\}\n\t\tautoAvailable \+= sku\.AutoStockAvailable\n#\tautoAvailable := int64(0)\n\tautoTotal := int64(0)\n\tautoLocked := int64(0)\n\tautoSold := int64(0)\n\thasLoopSKU := false\n\tfor _, sku := range product.SKUs {\n\t\tif !sku.IsActive {\n\t\t\tcontinue\n\t\t}\n\t\t// 循环发货规格用负数表示不限库存；若直接参与求和，会与其它规格的正数\n\t\t// 抵消成一个错误的具体数字（例如 -1 + 5 = 4 看起来还是低库存）。\n\t\tif sku.AutoStockAvailable < 0 {\n\t\t\thasLoopSKU = true\n\t\t\tcontinue\n\t\t}\n\t\tautoAvailable += sku.AutoStockAvailable\n#' "$PUBLIC"

    perl -0pi -e 's#\titem\.AutoStockAvailable = autoAvailable\n\titem\.AutoStockTotal = autoTotal\n#\tif hasLoopSKU {\n\t\titem.AutoStockAvailable = -1\n\t\titem.AutoStockTotal = -1\n\t\titem.AutoStockLocked = 0\n\t\titem.AutoStockSold = 0\n\t\titem.StockStatus = constants.ProductStockStatusUnlimited\n\t\titem.IsSoldOut = false\n\t\treturn\n\t}\n\titem.AutoStockAvailable = autoAvailable\n\titem.AutoStockTotal = autoTotal\n#' "$PUBLIC"
fi

grep -q 'hasLoopSKU' "$PUBLIC" || die "public_stock.go loop handling not inserted"
[ "$(grep -c 'hasLoopSKU' "$PUBLIC")" -ge 3 ] || die "public_stock.go loop handling incomplete"

# ---------------------------------------------------------------------------
# 3. dashboard inventory.go: 预警跳过循环规格（SQL 不动）
# ---------------------------------------------------------------------------
if ! grep -q 'detectLoopSecretSKUs' "$INVENTORY"; then
    # GetStockStats: 构造候选集
    perl -0pi -e 's#\t// 商品级别统计\n#\tloopSKUs := r.detectLoopSecretSKUs(skuAvailableMap)\n\n\t// 商品级别统计\n#' "$INVENTORY"

    # GetStockStats: 商品级预警跳过含循环规格的商品
    perl -0pi -e 's#\t\tavailable := productAvailableMap\[productID\]\n\t\tswitch classifyInventoryAlertType\(available, lowStockThreshold\) \{\n#\t\tif productHasLoopSKU(loopSKUs, productID) {\n\t\t\tcontinue\n\t\t}\n\t\tavailable := productAvailableMap[productID]\n\t\tswitch classifyInventoryAlertType(available, lowStockThreshold) {\n#' "$INVENTORY"

    # GetStockStats: 规格级预警跳过循环规格
    perl -0pi -e 's#\t\tfor _, skuID := range skuIDs \{\n\t\t\tskuAvail := int64\(0\)\n#\t\tfor _, skuID := range skuIDs {\n\t\t\tif _, isLoop := loopSKUs[loopSKUKey{productID: productID, skuID: skuID}]; isLoop {\n\t\t\t\tcontinue\n\t\t\t}\n\t\t\tskuAvail := int64(0)\n#' "$INVENTORY"

    # GetInventoryAlertItems: 构造候选集
    perl -0pi -e 's#\tupstreamMappingsByProduct := make\(map\[uint\]\[\]interface\{\}\)\n#\tloopSKUs := r.detectLoopSecretSKUs(autoAvailableMap)\n\n\tupstreamMappingsByProduct := make(map[uint][]interface{})\n#' "$INVENTORY"

    # GetInventoryAlertItems: 把候选集传给 auto 明细收集
    perl -0pi -e 's#collectAutoInventoryAlertRows\(product, autoAvailableMap\[product\.ID\], lowStockThreshold\)#collectAutoInventoryAlertRows(product, autoAvailableMap[product.ID], lowStockThreshold, loopSKUs)#' "$INVENTORY"

    # collectAutoInventoryAlertRows: 新参数 + 早退
    perl -0pi -e 's#func collectAutoInventoryAlertRows\(product productdomain\.Product, availableMap map\[uint\]int64, lowStockThreshold int64\) \[\]dashboard\.InventoryAlertRow \{\n\tresult := make\(\[\]dashboard\.InventoryAlertRow, 0\)\n#func collectAutoInventoryAlertRows(product productdomain.Product, availableMap map[uint]int64, lowStockThreshold int64, loopSKUs map[loopSKUKey]struct{}) []dashboard.InventoryAlertRow {\n\tresult := make([]dashboard.InventoryAlertRow, 0)\n\t// 循环发货规格不参与库存预警：其可用数量恒为 1，会稳定误报“低库存”。\n\tif productHasLoopSKU(loopSKUs, product.ID) {\n\t\treturn result\n\t}\n#' "$INVENTORY"
# 探测复用 cardsecret 的 store，需要两个新 import（contract 类型 + store 实现）
    grep -q 'cardsecret/infrastructure/gormstore"' "$INVENTORY" || \
        perl -0pi -e 's#(cardsecretdomain "github\.com/dujiao-next/internal/modules/cardsecret/domain"\n)#cardsecretcontract "github.com/dujiao-next/internal/modules/cardsecret/contract"\n\tcardsecretdomain "github.com/dujiao-next/internal/modules/cardsecret/domain"\n\tcardsecretgormstore "github.com/dujiao-next/internal/modules/cardsecret/infrastructure/gormstore"\n#' "$INVENTORY"

    cat >> "$INVENTORY" <<'EOF'

// loopSKUKey 标识商品下的一个规格。
type loopSKUKey struct {
	productID uint
	skuID     uint
}

const loopSecretProbeLimit = 1000

// detectLoopSecretSKUs 只在“可用数量为 1”的候选规格里探测循环发货规格。
// 循环规格的可用数量恒为 1（见 cardsecret 导入校验），所以高库存规格永远
// 不会被探测，探测成本只与候选数量相关，与库存总量无关。
//
// 探测复用 cardsecret 的 FindLoopSecretSKUs，不在这里重写一份 SQL：
// order 的 gormstore/transaction.go 也是这么跨模块取 store 的。若各自复制，
// 前缀匹配、deleted_at 过滤、分批大小这些细节会慢慢漂移，而这类漂移不报错，
// 只会让预警数字和商品列表对不上。
func (r *Store) detectLoopSecretSKUs(availableMap map[uint]map[uint]int64) map[loopSKUKey]struct{} {
	candidates := make([]cardsecretcontract.LoopSKU, 0)
	for productID, skuMap := range availableMap {
		for skuID, total := range skuMap {
			if skuID == 0 || total != 1 {
				continue
			}
			candidates = append(candidates, cardsecretcontract.LoopSKU{ProductID: productID, SKUID: skuID})
		}
	}
	if len(candidates) == 0 {
		return nil
	}
	if len(candidates) > loopSecretProbeLimit {
		candidates = candidates[:loopSecretProbeLimit]
	}
	found, err := cardsecretgormstore.New(r.db).FindLoopSecretSKUs(candidates)
	if err != nil {
		// 探测失败时降级为“不识别”，不影响预警本身
		return nil
	}
	result := make(map[loopSKUKey]struct{}, len(found))
	for _, item := range found {
		result[loopSKUKey{productID: item.ProductID, skuID: item.SKUID}] = struct{}{}
	}
	return result
}

func productHasLoopSKU(loopSKUs map[loopSKUKey]struct{}, productID uint) bool {
	for key := range loopSKUs {
		if key.productID == productID {
			return true
		}
	}
	return false
}
EOF
fi

grep -q 'detectLoopSecretSKUs' "$INVENTORY" || die "dashboard probe not inserted"
grep -q 'productHasLoopSKU(loopSKUs, productID)' "$INVENTORY" || die "dashboard product alert guard missing"
grep -q 'loopSKUs map\[loopSKUKey\]struct{}' "$INVENTORY" || die "collectAutoInventoryAlertRows signature not updated"
grep -q 'cardsecretgormstore.New(r.db).FindLoopSecretSKUs' "$INVENTORY" || die "dashboard must reuse cardsecret store instead of duplicating probe SQL"
if grep -q 'substr(secret, 1, ?)' "$INVENTORY"; then
    die "dashboard must not keep its own loop-secret SQL (it drifts from cardsecret store)"
fi
if grep -q 'loopSecretProbeBatch' "$INVENTORY"; then
    die "loopSecretProbeBatch should be gone (batching lives in cardsecret store)"
fi

command -v gofmt >/dev/null 2>&1 && gofmt -w "$STOCK" "$PUBLIC" "$INVENTORY"

echo "loop-card-secret/004: OK"
