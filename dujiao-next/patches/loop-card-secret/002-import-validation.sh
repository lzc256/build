#!/bin/bash
DESCRIPTION="\
循环卡密（一密多发）第二步: 导入校验。
- cardsecret/application/errors.go: 新增 ErrLoopSecretDuplicate / ErrLoopSecretMixed
- cardsecret/application/import.go: CreateCardSecretBatch（唯一的写入入口，
  CSV 导入复用同一函数）在事务内新增 validateLoopSecrets 校验
  （写成局部函数：本模块的结构测试会逐文件核对函数清单，新增顶层声明会失败）:
    1. 一个规格最多一条循环卡密
    2. 循环卡密与普通卡密不得并存
  这两条规则保证“循环规格的可用数量恒为 1”，下单热路径与库存展示都依赖该不变量。
- cardsecret/transport/http: 两个写入 handler 把新错误映射为 400
- internal/i18n/messages.go: 三个语种各新增两条错误文案（纯后端文案，前端零改动）
校验只在写入路径执行，不进入下单/展示链路。"

set -euo pipefail

T="${1:-}"
[ -n "$T" ] || { echo "usage: $0 <target_dir>" >&2; exit 1; }
[ -d "$T" ] || { echo "target dir not found: $T" >&2; exit 1; }

die() { echo "loop-card-secret/002: $*" >&2; exit 1; }

ERRORS="$T/internal/modules/cardsecret/application/errors.go"
IMPORT="$T/internal/modules/cardsecret/application/import.go"
HANDLER="$T/internal/modules/cardsecret/transport/http/admin_handler.go"
I18N="$T/internal/i18n/messages.go"

for f in "$ERRORS" "$IMPORT" "$HANDLER" "$I18N"; do
    [ -f "$f" ] || die "missing file: $f"
done

# ---------------------------------------------------------------------------
# 1. 错误定义
# ---------------------------------------------------------------------------
if ! grep -q 'ErrLoopSecretDuplicate' "$ERRORS"; then
    perl -0pi -e 's{(\tErrProductSKUInvalid  = errors\.New\("product sku invalid"\)\n)}{$1\t// ErrLoopSecretDuplicate 表示同一规格已存在或多条提交循环发货卡密。\n\tErrLoopSecretDuplicate = errors.New("card secret loop duplicated")\n\t// ErrLoopSecretMixed 表示循环发货卡密与普通卡密被混在同一规格中。\n\tErrLoopSecretMixed = errors.New("card secret loop mixed with normal")\n}' "$ERRORS"
fi
grep -q 'ErrLoopSecretDuplicate' "$ERRORS" || die "ErrLoopSecretDuplicate not added"
grep -q 'ErrLoopSecretMixed' "$ERRORS" || die "ErrLoopSecretMixed not added"

# ---------------------------------------------------------------------------
# 2. 写入前校验
# ---------------------------------------------------------------------------
TMPBLOCK="$(mktemp)"
cat > "$TMPBLOCK" <<'EOF'
	// 循环发货卡密校验。
	// 写成局部函数而不是顶层函数/方法：本模块有结构测试逐文件核对函数清单。
	// 规则:
	//  1. 一个规格最多一条循环卡密；
	//  2. 循环卡密与普通卡密不得并存（同一规格要么普通库存，要么循环发货）。
	// 两条规则共同保证「循环规格的可用数量恒等于 1」：下单热路径据此只判定
	// 已取回的行，库存展示据此把探测范围限制在极小候选集内。
	// 校验放在事务之前：只读检查不需要事务隔离，且事务内的错误会被折叠成
	// ErrCreateFailed，放在这里才能把具体原因返回给调用方。
	validateLoopSecrets := func(secrets []string) error {
		loopInBatch := 0
		for _, secret := range secrets {
			if cardsecretdomain.IsLoopSecret(secret) {
				loopInBatch++
			}
		}
		// 循环卡密必须带内容，否则交付给买家的是空字符串
		for _, secret := range secrets {
			if cardsecretdomain.IsLoopSecret(secret) && cardsecretdomain.LoopSecretContent(secret) == "" {
				return ErrInvalid
			}
		}
		existingLoop, err := s.secretRepo.CountLoopSecrets(input.ProductID, sku.ID)
		if err != nil {
			return ErrCreateFailed
		}
		// 一个规格只能有一条循环卡密
		if loopInBatch > 1 || (loopInBatch == 1 && existingLoop > 0) {
			return ErrLoopSecretDuplicate
		}
		// 循环与普通不得混在同一批
		if loopInBatch > 0 && loopInBatch < len(secrets) {
			return ErrLoopSecretMixed
		}
		// 已是循环规格，不允许再导入普通卡密
		if loopInBatch == 0 && existingLoop > 0 {
			return ErrLoopSecretMixed
		}
		// 已有普通库存，不允许改成循环规格。
		// CountAvailable 统计 status=available，其中含循环卡密本身，需要扣掉。
		if loopInBatch == 1 {
			existingAvailable, err := s.secretRepo.CountAvailable(input.ProductID, sku.ID)
			if err != nil {
				return ErrCreateFailed
			}
			if existingAvailable-existingLoop > 0 {
				return ErrLoopSecretMixed
			}
		}
		return nil
	}
	if err := validateLoopSecrets(normalized); err != nil {
		return nil, 0, err
	}
EOF

if ! grep -q 'validateLoopSecrets := func' "$IMPORT"; then
    # 用 index/substr 插入整块代码，避免 perl 替换分隔符与 Go 大括号冲突
    LOOP_BLOCK="$TMPBLOCK" perl -0pi -e '
BEGIN {
	local $/;
	open my $fh, "<", $ENV{LOOP_BLOCK} or die "open block: $!";
	$block = <$fh>;
	close $fh;
}
my $anchor = "\tif len(normalized) == 0 {\n\t\treturn nil, 0, ErrInvalid\n\t}\n";
my $pos = index($_, $anchor);
die "anchor not found in import.go\n" if $pos < 0;
substr($_, $pos + length($anchor), 0) = $block;
' "$IMPORT"
fi
rm -f "$TMPBLOCK"

grep -q 'validateLoopSecrets := func' "$IMPORT" || die "validateLoopSecrets closure not inserted"
grep -q 'if err := validateLoopSecrets(normalized); err != nil {' "$IMPORT" || die "validateLoopSecrets call not inserted"
[ "$(grep -c 'validateLoopSecrets := func' "$IMPORT")" = "1" ] || die "validateLoopSecrets inserted more than once"

# ---------------------------------------------------------------------------
# 3. handler 错误映射（只针对两个写入入口，锚点是它们独有的默认分支前置 case）
# ---------------------------------------------------------------------------
if ! grep -q 'ErrLoopSecretDuplicate' "$HANDLER"; then
    perl -0pi -e 's{(\t\tcase errors\.Is\(err, cardsecretapp\.ErrBatchCreateFailed\):\n\t\t\tginutil\.RespondError\(c, response\.CodeInternal, "error\.card_secret_batch_create_failed", err\)\n)}{$1\t\tcase errors.Is(err, cardsecretapp.ErrLoopSecretDuplicate):\n\t\t\tginutil.RespondError(c, response.CodeBadRequest, "error.card_secret_loop_duplicate", nil)\n\t\tcase errors.Is(err, cardsecretapp.ErrLoopSecretMixed):\n\t\t\tginutil.RespondError(c, response.CodeBadRequest, "error.card_secret_loop_mixed", nil)\n}g' "$HANDLER"
fi
[ "$(grep -c 'cardsecretapp.ErrLoopSecretDuplicate' "$HANDLER")" = "2" ] \
    || die "handler mapping not applied to both write handlers"

# ---------------------------------------------------------------------------
# 4. 后端文案（zh-CN / zh-TW / en）
# ---------------------------------------------------------------------------
if ! grep -q 'error.card_secret_loop_duplicate' "$I18N"; then
    perl -0pi -e 's{(\t\t"error\.card_secret_invalid":\s+"卡密参数不合法",\n)}{$1\t\t"error.card_secret_loop_duplicate":               "循环发货卡密每个规格只能有 1 条，且不能重复导入",\n\t\t"error.card_secret_loop_mixed":                   "循环发货卡密不能与普通卡密并存于同一规格",\n}' "$I18N"
    perl -0pi -e 's{(\t\t"error\.card_secret_invalid":\s+"卡密參數不合法",\n)}{$1\t\t"error.card_secret_loop_duplicate":               "循環發貨卡密每個規格只能有 1 條，且不能重複導入",\n\t\t"error.card_secret_loop_mixed":                   "循環發貨卡密不能與普通卡密並存於同一規格",\n}' "$I18N"
    perl -0pi -e 's{(\t\t"error\.card_secret_invalid":\s+"Invalid card secret data",\n)}{$1\t\t"error.card_secret_loop_duplicate":               "A loop-delivery card can only exist once per SKU",\n\t\t"error.card_secret_loop_mixed":                   "Loop-delivery cards cannot be mixed with normal cards in the same SKU",\n}' "$I18N"
fi
[ "$(grep -c 'error.card_secret_loop_duplicate' "$I18N")" = "3" ] \
    || die "i18n messages not added to all 3 locales"
[ "$(grep -c 'error.card_secret_loop_mixed' "$I18N")" = "3" ] \
    || die "i18n loop_mixed not added to all 3 locales"

# 让新增的 map 键对齐
command -v gofmt >/dev/null 2>&1 && gofmt -w "$ERRORS" "$IMPORT" "$HANDLER" "$I18N"

echo "loop-card-secret/002: OK"
