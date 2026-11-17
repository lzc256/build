#!/usr/bin/env bash
# 清理 dujiao-next 已软删除的卡密，并回收 SQLite 磁盘空间。
# 后台"删除卡密"只写 deleted_at，行还在表里；DELETE 也只是把页放进 freelist，
# 不 VACUUM 文件不会变小。
#
# 用法: ./purge-dangling-card-secrets.sh <数据库路径>
#
# 只删未发货的已删除卡密：status='available' 且没有订单占用。
# 已发货(used)的保留——它是"哪条卡密发给了哪个订单"的唯一凭据，删了不可恢复；
# 待发货(reserved)的也保留——删了在途订单会发不出货。

set -euo pipefail

DB="${1:?用法: $0 <数据库路径>}"
[ -f "$DB" ] || { echo "找不到数据库: ${DB}"; exit 1; }

WHERE="deleted_at IS NOT NULL
   AND status = 'available'
   AND order_id IS NULL
   AND reserved_at IS NULL
   AND used_at IS NULL"

COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM card_secrets WHERE $WHERE;")
if [ "$COUNT" -eq 0 ]; then
    echo "没有未发货的已删除卡密，无需清理"
    exit 0
fi

echo "将删除："
sqlite3 "$DB" "
SELECT CASE WHEN length(secret) > 40 THEN substr(secret, 1, 40) || '...' ELSE secret END
FROM card_secrets WHERE $WHERE ORDER BY id LIMIT 10;" | nl -ba -w2 -s'. '
if [ "$COUNT" -gt 10 ]; then
    echo "  ..."
fi
echo "共 $COUNT 行（${DB} 当前 $(du -h "$DB" | cut -f1)）"

read -r -p "确认？[y/N] " ans
case "$ans" in y|Y) ;; *) echo "已取消"; exit 0 ;; esac

BACKUP="./$(basename "$DB" .db).db.$(date +%Y%m%d-%H%M%S).bak"
sqlite3 "$DB" "VACUUM INTO '$BACKUP';"
echo "已备份: ${BACKUP}（$(du -h "$BACKUP" | cut -f1)）"

sqlite3 "$DB" "DELETE FROM card_secrets WHERE $WHERE; VACUUM;"

echo "完成: $(du -h "$DB" | cut -f1)，剩余 $(sqlite3 "$DB" 'SELECT COUNT(*) FROM card_secrets;') 行"
