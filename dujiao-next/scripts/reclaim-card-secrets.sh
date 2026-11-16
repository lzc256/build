#!/usr/bin/env bash
#
# 回收 dujiao-next（SQLite）因软删除占用的磁盘空间。
#
# 背景：后台“删除卡密”只是把 card_secrets.deleted_at 写上一个时间戳，
# 行本身永久留在表里（全仓库没有硬删除路径）。这些行对应用完全不可见
# （所有查询都带 deleted_at IS NULL），但会一直占着文件体积。
# SQLite 的 DELETE 也只把页放进 freelist，文件不会变小，必须 VACUUM 才真正还盘。
#
# 用法：
#   ./reclaim-card-secrets.sh <db-path> [选项]
#
#   -n, --days N        只清理 deleted_at 早于 N 天的行（默认 0 = 全部已删除行）
#   -b, --batch N       每批删除行数（默认 5000，控制单次事务与 WAL 增量）
#   -o, --out DIR       备份目录（默认与数据库同级的 ./reclaim-backup-<时间戳>）
#   -f, --force         跳过交互确认（自动化用）
#       --dry-run       只统计，不做任何修改
#       --no-backup     跳过备份（不推荐）
#       --vacuum-only   只做 VACUUM，不删除任何行
#       --no-vacuum     只删除不 VACUUM（空间不会立即回收）
#   -h, --help          显示帮助
#
# 退出码：0 成功；1 参数/环境错误；2 备份失败；3 删除失败；4 VACUUM/校验失败。
#
# 注意：
#   * VACUUM 需要独占访问，临时需要约等于当前文件大小的空闲磁盘。
#     请在应用停机窗口执行，或至少确认没有正在进行的导入/下单写入。
#   * 备份用 `VACUUM INTO` 生成一致性快照，应用运行时也安全。
#   * card_secrets 只有指向 card_secret_batches 的外键（它是子表），
#     没有任何表引用它；订单交付内容存在 fulfillments.payload 文本里，
#     因此删除历史行不影响历史订单展示。
#   * 时间比较：GORM 把 deleted_at 写成带时区偏移的本地时间
#     （如 2026-11-15 14:53:13.549729+08:00），而 SQLite 的 datetime('now')
#     是 UTC。直接比字符串会在时区边界上错 8 小时，所以用 julianday() 做精确
#     比较，另加一个 “+1 天” 的粗边界让索引仍能被用上。

set -euo pipefail

PROG="$(basename "$0")"

die() { echo "$PROG: $*" >&2; exit "${2:-1}"; }
info() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

usage() { awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"; exit 0; }

DAYS=0
BATCH=5000
OUT_DIR=""
FORCE=0
DRY_RUN=0
NO_BACKUP=0
VACUUM_ONLY=0
NO_VACUUM=0
DB=""

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage ;;
        -n|--days) DAYS="${2:?--days 需要参数}"; shift 2 ;;
        -b|--batch) BATCH="${2:?--batch 需要参数}"; shift 2 ;;
        -o|--out) OUT_DIR="${2:?--out 需要参数}"; shift 2 ;;
        -f|--force) FORCE=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        --no-backup) NO_BACKUP=1; shift ;;
        --vacuum-only) VACUUM_ONLY=1; shift ;;
        --no-vacuum) NO_VACUUM=1; shift ;;
        -*) die "未知选项: $1" 1 ;;
        *) DB="$1"; shift ;;
    esac
done

[ -n "$DB" ] || die "缺少数据库路径（用 -h 查看用法）" 1
[ -f "$DB" ] || die "数据库文件不存在: $DB" 1
command -v sqlite3 >/dev/null 2>&1 || die "需要 sqlite3 命令行工具" 1

case "$DAYS" in ''|*[!0-9]*) die "--days 必须是非负整数" 1 ;; esac
case "$BATCH" in ''|*[!0-9]*) die "--batch 必须是正整数" 1 ;; esac
[ "$BATCH" -gt 0 ] || die "--batch 必须大于 0" 1

DB_DIR="$(cd "$(dirname "$DB")" && pwd)"
DB_NAME="$(basename "$DB")"
DB_ABS="$DB_DIR/$DB_NAME"
TS="$(date +%Y%m%d-%H%M%S)"

# 只读查询：.timeout 是 CLI 点命令，不像 PRAGMA busy_timeout 会把值打印出来
q()   { sqlite3 -batch -noheader "$DB_ABS" -cmd ".timeout 30000" "$1"; }
qw()  { sqlite3 -batch -noheader "$DB_ABS" -cmd ".timeout 30000"; }

file_size() { stat -f%z "$1" 2>/dev/null || stat -c%s "$1"; }
human() { awk -v b="${1:-0}" 'BEGIN{ split("B KB MB GB TB",u," "); i=1; while (b>=1024 && i<5) { b/=1024; i++ } printf (i==1 ? "%d%s" : "%.1f%s"), b, u[i] }'; }

# --- 环境检查 ---------------------------------------------------------------
[ -f "$DB_ABS-wal" ] && [ -s "$DB_ABS-wal" ] && warn "存在非空 WAL 文件（应用可能仍在运行）：$DB_ABS-wal"
q "SELECT 1 FROM sqlite_master WHERE type='table' AND name='card_secrets';" | grep -q 1 \
    || die "$DB_ABS 里没有 card_secrets 表，确认这是 dujiao-next 的数据库" 1

if [ "$FORCE" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    echo "即将处理: $DB_ABS"
    echo "应用必须处于停止状态（VACUUM 需独占访问）。"
    printf '继续？[y/N] '
    read -r ans || ans=""
    case "$ans" in y|Y) ;; *) echo "已取消"; exit 0 ;; esac
fi

JOURNAL="$(q 'PRAGMA journal_mode;' | tr -d '\r')"
PAGE_SIZE="$(q 'PRAGMA page_size;' | tr -d '\r')"
info "数据库:   $DB_ABS"
info "journal:  $JOURNAL    page_size: $PAGE_SIZE"
info "文件大小: $(human "$(file_size "$DB_ABS")")"

# --- 统计 -------------------------------------------------------------------
# 精确条件：julianday 会把带偏移的时间正规化成 UTC 再比，避免 8 小时误差
if [ "$DAYS" -gt 0 ]; then
    COARSE="deleted_at < datetime('now','-$DAYS days','+1 day') AND julianday(deleted_at) < julianday('now','-$DAYS days')"
else
    COARSE="1=1"
fi
TARGET="$(q "SELECT COUNT(*) FROM card_secrets WHERE deleted_at IS NOT NULL AND $COARSE;" | tr -d '\r')"
TOTAL="$(q 'SELECT COUNT(*) FROM card_secrets;' | tr -d '\r')"
DELETED="$(q 'SELECT COUNT(*) FROM card_secrets WHERE deleted_at IS NOT NULL;' | tr -d '\r')"
LIVE="$(q 'SELECT COUNT(*) FROM card_secrets WHERE deleted_at IS NULL;' | tr -d '\r')"
PAGES="$(q 'PRAGMA page_count;' | tr -d '\r')"
FREE_PAGES="$(q 'PRAGMA freelist_count;' | tr -d '\r')"

info ""
info "card_secrets 总行数:      $TOTAL"
info "  已软删除(全部):        $DELETED"
info "  本次待清理(>${DAYS}天): $TARGET"
info "  存活行(保留):          $LIVE"
info "页数: $PAGES  空闲页: $FREE_PAGES ($(human $(( FREE_PAGES * PAGE_SIZE ))))"

# 顺带统计其他表的软删除残留，只报告不动手
for t in card_secret_batches orders order_items fulfillments; do
    if q "SELECT 1 FROM sqlite_master WHERE type='table' AND name='$t';" | grep -q 1; then
        n="$(q "SELECT COUNT(*) FROM $t WHERE deleted_at IS NOT NULL;" 2>/dev/null | tr -d '\r')"
        [ -n "${n:-}" ] && info "  $t 软删除残留: $n"
    fi
done

if [ "$DRY_RUN" -eq 1 ]; then
    info ""
    info "[dry-run] 未做任何修改"
    exit 0
fi

# --- 备份 -------------------------------------------------------------------
BACKUP=""
if [ "$NO_BACKUP" -eq 0 ]; then
    OUT_DIR="${OUT_DIR:-$DB_DIR/reclaim-backup-$TS}"
    mkdir -p "$OUT_DIR"
    BACKUP="$OUT_DIR/$DB_NAME"
    info ""
    info "备份中 -> $BACKUP"
    # VACUUM INTO 生成一致性快照（应用运行时也安全），且顺带去掉 freelist
    sqlite3 -batch "$DB_ABS" -cmd ".timeout 30000" "VACUUM INTO '$BACKUP';" || die "备份失败" 2
    info "备份完成: $(human "$(file_size "$BACKUP")")"
else
    warn "已跳过备份（--no-backup）"
fi

# --- 删除 -------------------------------------------------------------------
REMOVED=0
if [ "$VACUUM_ONLY" -eq 0 ]; then
    if [ "$TARGET" -gt 0 ]; then
        info ""
        info "分批删除（每批 $BATCH 行）..."
        while :; do
            # SQLite 的 DELETE 不支持 LIMIT（除非编译开启 SQLITE_ENABLE_UPDATE_DELETE_LIMIT），
            # 用子查询限定一批 id；DELETE 与 changes() 放在同一事务里。
            out="$(qw <<SQL
BEGIN IMMEDIATE;
DELETE FROM card_secrets WHERE id IN (
    SELECT id FROM card_secrets
    WHERE deleted_at IS NOT NULL AND $COARSE
    ORDER BY id
    LIMIT $BATCH
);
SELECT changes();
COMMIT;
SQL
)" || die "删除失败" 3
            n="$(printf '%s' "$out" | tr -d '\r' | tail -1)"
            case "$n" in ''|*[!0-9]*) die "无法解析删除行数: '$n'" 3 ;; esac
            [ "$n" -gt 0 ] || break
            REMOVED=$((REMOVED + n))
            printf '  已删除 %d / %d\r' "$REMOVED" "$TARGET"
        done
        printf '\n'
        info "删除完成: $REMOVED 行"
        if [ "$REMOVED" -ne "$TARGET" ]; then
            warn "实际删除 $REMOVED 行，与统计的 $TARGET 不一致（可能有并发写入）"
        fi
        # 删除后把 WAL 落盘并截断，否则空间只是挪到 -wal 里
        q 'PRAGMA wal_checkpoint(TRUNCATE);' >/dev/null || warn "wal_checkpoint(TRUNCATE) 失败（可能仍有连接占用）"
    else
        info "没有符合条件的行，跳过删除"
    fi
fi

# --- VACUUM -----------------------------------------------------------------
if [ "$NO_VACUUM" -eq 0 ]; then
    SIZE_BEFORE="$(file_size "$DB_ABS")"
    FREE_KB="$(df -Pk "$DB_DIR" | awk 'NR==2{print $4}')"
    NEED_KB=$(( SIZE_BEFORE / 1024 ))
    info ""
    info "VACUUM 前: $(human "$SIZE_BEFORE")，分区可用 $(human $(( FREE_KB * 1024 )))，需要约 $(human $(( NEED_KB * 1024 )))"
    if [ "$FREE_KB" -lt "$NEED_KB" ]; then
        warn "可用空间可能不足，改用 VACUUM INTO 重建（只需紧凑后大小）后原子替换"
        TMP_DB="$DB_ABS.vacuum-$TS"
        # 顺序很关键：先把 WAL 合并回主库并清空，再重建，最后替换。
        # 若不先 checkpoint，残留的 -wal/-shm 会被套用到新文件上，导致数据错乱。
        q 'PRAGMA wal_checkpoint(TRUNCATE);' >/dev/null 2>&1 || warn "checkpoint 未完成，请确认应用已停止"
        sqlite3 -batch "$DB_ABS" -cmd ".timeout 30000" "VACUUM INTO '$TMP_DB';" || die "VACUUM INTO 失败" 4
        rm -f "$DB_ABS-wal" "$DB_ABS-shm"
        mv "$TMP_DB" "$DB_ABS"
    else
        qw <<'SQL' || die "VACUUM 失败" 4
PRAGMA foreign_keys=OFF;
VACUUM;
SQL
        q 'PRAGMA wal_checkpoint(TRUNCATE);' >/dev/null 2>&1 || true
    fi
    SIZE_AFTER="$(file_size "$DB_ABS")"
    info "VACUUM 后: $(human "$SIZE_AFTER")，回收 $(human $(( SIZE_BEFORE - SIZE_AFTER )))"
else
    warn "已跳过 VACUUM（--no-vacuum）：行已删除，但磁盘空间尚未释放"
fi

# --- 校验 -------------------------------------------------------------------
info ""
info "完整性校验..."
CHECK="$(q 'PRAGMA quick_check;' | tr -d '\r' | head -1)"
[ "$CHECK" = "ok" ] || die "quick_check 未通过: $CHECK" 4
FK="$(q 'PRAGMA foreign_key_check;' | tr -d '\r')"
[ -z "$FK" ] || warn "外键检查发现不一致: $FK"

info "剩余 card_secrets: $(q 'SELECT COUNT(*) FROM card_secrets;' | tr -d '\r') 行（存活 $(q 'SELECT COUNT(*) FROM card_secrets WHERE deleted_at IS NULL;' | tr -d '\r') 行）"
info "文件大小: $(human "$(file_size "$DB_ABS")")"
[ -n "$BACKUP" ] && info "备份保留在: $BACKUP"
info "完成。"
