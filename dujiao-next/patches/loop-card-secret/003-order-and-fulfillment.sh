#!/bin/bash
DESCRIPTION="\
循环卡密（一密多发）第三步: 下单与发货链路。
- cardsecret/domain: 新增 FirstLoopSecret(secrets) —— 按调用方顺序返回第一条循环卡密。
  下单和发货两个模块共用它，避免各自实现前缀判断。
- order/application: auto 履约下单取回 <=quantity 行后，只要命中循环卡密
  就跳过库存校验与 Reserve（否则那张卡密会被 reserved/used，第二次就发不出去）。
  未命中时逻辑与上游逐字一致。SQL 完全不变。
- fulfillment/application: 命中循环卡密时把内容重复 quantity 次写入 payload，
  且不把该行放进 ids，因此不会 MarkUsed。人工发货(CreateManual)完全不碰
  card_secrets，行为不变。
所有判定都在“已经取回的行”上做，不新增任何查询，也不引入 O(N) 扫描。"

set -euo pipefail

T="${1:-}"
[ -n "$T" ] || { echo "usage: $0 <target_dir>" >&2; exit 1; }
[ -d "$T" ] || { echo "target dir not found: $T" >&2; exit 1; }

die() { echo "loop-card-secret/003: $*" >&2; exit 1; }

DOMAIN="$T/internal/modules/cardsecret/domain/secret.go"
ORDER="$T/internal/modules/order/application/order_service.go"
FULFILL="$T/internal/modules/fulfillment/application/service.go"

for f in "$DOMAIN" "$ORDER" "$FULFILL"; do
    [ -f "$f" ] || die "missing file: $f"
done

# 说明: 本脚本的 perl 替换统一用 '#' 作分隔符。
# 插入的是 Go 代码，替换文本中必然出现 { } != && 等字符，
# 用 s{}{} 会因括号嵌套被截断，用 s!! 会因 != 被截断。

# ---------------------------------------------------------------------------
# 1. 领域：FirstLoopSecret
# ---------------------------------------------------------------------------
if ! grep -q 'func FirstLoopSecret' "$DOMAIN"; then
    cat >> "$DOMAIN" <<'EOF'

// FirstLoopSecret 按给定顺序返回第一条循环发货卡密，未命中返回 nil。
// 调用方传入的行已经按 id 升序（ListAvailableByProduct* 的 Order("id asc")），
// 因此多条循环卡密共存时行为是确定的：id 最小的一条生效。
func FirstLoopSecret(secrets []Secret) *Secret {
	for i := range secrets {
		if IsLoopSecret(secrets[i].Secret) {
			return &secrets[i]
		}
	}
	return nil
}
EOF
fi
grep -q 'func FirstLoopSecret' "$DOMAIN" || die "FirstLoopSecret not added"

# ---------------------------------------------------------------------------
# 2. 下单：循环规格不参与库存校验与占用
# ---------------------------------------------------------------------------
if ! grep -q 'cardsecretdomain.FirstLoopSecret(rows)' "$ORDER"; then
    # 补 import
    grep -q 'modules/cardsecret/domain"' "$ORDER" || \
        perl -0pi -e 's#(\taffiliatedomain "github\.com/dujiao-next/internal/modules/affiliate/domain"\n)#$1\tcardsecretdomain "github.com/dujiao-next/internal/modules/cardsecret/domain"\n#' "$ORDER"

    # 库存不足判定跳过循环规格（只改这一行，不重排既有代码）
    perl -0pi -e 's#\t\t\t\tif len\(rows\) < plan\.Item\.Quantity \{\n#\t\t\t\t// 循环发货规格: 取回的行里只要命中循环卡密，就整单重复发放该内容，\n\t\t\t\t// 不占用任何卡密行（否则该卡密被标记 reserved/used 后无法再次发货）。\n\t\t\t\tif len(rows) < plan.Item.Quantity && cardsecretdomain.FirstLoopSecret(rows) == nil {\n#' "$ORDER"

    # 不把循环卡密行加入待占用列表（Reserve 收到空列表时返回 0，后续校验自然通过）
    perl -0pi -e 's#\t\t\t\tids := make\(\[\]uint, 0, len\(rows\)\)\n\t\t\t\tfor _, row := range rows \{\n\t\t\t\t\tids = append\(ids, row\.ID\)\n\t\t\t\t\}\n#\t\t\t\tids := make([]uint, 0, len(rows))\n\t\t\t\tif cardsecretdomain.FirstLoopSecret(rows) == nil {\n\t\t\t\t\tfor _, row := range rows {\n\t\t\t\t\t\tids = append(ids, row.ID)\n\t\t\t\t\t}\n\t\t\t\t}\n#' "$ORDER"
fi

grep -q 'modules/cardsecret/domain"' "$ORDER" || die "cardsecretdomain import missing in order_service"
[ "$(grep -c 'cardsecretdomain.FirstLoopSecret(rows)' "$ORDER")" = "2" ] || die "order guard not applied to both spots"

# ---------------------------------------------------------------------------
# 3. 发货：循环规格重复内容且不标记已用
# ---------------------------------------------------------------------------
if ! grep -q 'cardsecretdomain.FirstLoopSecret(selected)' "$FULFILL"; then
    # secretLines 提前到 item 循环之前声明
    perl -0pi -e 's#\t\tvar secrets \[\]cardsecretdomain\.Secret\n#\t\tvar secrets []cardsecretdomain.Secret\n\t\tsecretLines := make([]string, 0, len(order.Items))\n#' "$FULFILL"

    # 命中循环卡密的分支（放在库存不足判定之前）
    perl -0pi -e 's#\t\t\tif len\(selected\) < item\.Quantity \{\n#\t\t\t// 循环发货规格: 整单重复发放同一内容，且不进入 ids（不标记已用）。\n\t\t\tif loopSecret := cardsecretdomain.FirstLoopSecret(selected); loopSecret != nil {\n\t\t\t\tcontent := cardsecretdomain.LoopSecretContent(loopSecret.Secret)\n\t\t\t\tfor i := 0; i < item.Quantity; i++ {\n\t\t\t\t\tsecretLines = append(secretLines, content)\n\t\t\t\t}\n\t\t\t\tcontinue\n\t\t\t}\n\t\t\tif len(selected) < item.Quantity {\n#' "$FULFILL"

    # 普通卡密逐条进入交付内容
    perl -0pi -e 's#\t\t\tsecrets = append\(secrets, selected\.\.\.\)\n#\t\t\tsecrets = append(secrets, selected...)\n\t\t\tfor _, secret := range selected {\n\t\t\t\tsecretLines = append(secretLines, secret.Secret)\n\t\t\t}\n#' "$FULFILL"

    # 原来的交付内容构建改为只收集 ids
    perl -0pi -e 's#\t\tids := make\(\[\]uint, 0, len\(secrets\)\)\n\t\tsecretLines := make\(\[\]string, 0, len\(secrets\)\)\n\t\tfor _, secret := range secrets \{\n\t\t\tids = append\(ids, secret\.ID\)\n\t\t\tsecretLines = append\(secretLines, secret\.Secret\)\n\t\t\}\n#\t\tids := make([]uint, 0, len(secrets))\n\t\tfor _, secret := range secrets {\n\t\t\tids = append(ids, secret.ID)\n\t\t}\n#' "$FULFILL"
fi

grep -q 'cardsecretdomain.FirstLoopSecret(selected)' "$FULFILL" || die "fulfillment loop branch not applied"
grep -q 'secretLines := make(\[\]string, 0, len(order.Items))' "$FULFILL" || die "secretLines declaration missing"
[ "$(grep -c 'secretLines := make' "$FULFILL")" = "1" ] || die "secretLines declared more than once"
grep -q 'secretLines = append(secretLines, secret.Secret)' "$FULFILL" || die "normal secret lines not collected"

command -v gofmt >/dev/null 2>&1 && gofmt -w "$DOMAIN" "$ORDER" "$FULFILL"

echo "loop-card-secret/003: OK"
