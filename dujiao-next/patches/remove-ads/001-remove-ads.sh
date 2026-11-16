#!/bin/bash
DESCRIPTION="\
移除上游内置的广告代理模块（后台仪表盘广告位）:
- 删除后端 internal/modules/adproxy 整个模块（10 文件 / 约 418 行）
- 删除容器装配、管理端路由注册、RBAC 两条策略、架构守卫测试
- 删除前端 DashboardAd.vue 组件与仪表盘 3 个广告位挂载点
- 删除前端 api/types/i18n 中的广告类型与文案

采用脚本而非 .patch 的原因: 本补丁以\"整文件删除 + 少量锚点删除\"为主，
rm -rf + 锚点正则天然幂等、不依赖行号或上下文哈希，上游对这些文件的
改动不会让本补丁 3-way 冲突；脚本末尾有残留断言，漂移时会立刻失败。
用户端（frontend/user）从来没有任何广告代码，无需改动。"

set -euo pipefail

T="${1:-}"
[ -n "$T" ] || { echo "usage: $0 <target_dir>" >&2; exit 1; }
[ -d "$T" ] || { echo "target dir not found: $T" >&2; exit 1; }

die() { echo "remove-ads: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. 删除整个后端广告模块、架构守卫、前端广告组件
#    （文件不存在也不报错，保证脚本可重复执行）
# ---------------------------------------------------------------------------
rm -rf "$T/internal/modules/adproxy"
rm -f "$T/internal/architecture/adproxy_handler_structure_test.go"
rm -f "$T/frontend/admin/src/components/admin/DashboardAd.vue"

# ---------------------------------------------------------------------------
# 2. 管理端路由注册
# ---------------------------------------------------------------------------
ROUTES="$T/internal/app/httpserver/routes_admin.go"
if [ -f "$ROUTES" ]; then
    perl -0pi -e 's{^[^\n]*modules/adproxy/transport/http"\n}{}m' "$ROUTES"
    perl -0pi -e 's{\n[ \t]*// 广告代理\n[^\n]*adproxytransport\.RegisterAdminRoutes\([^\n]*\n}{}' "$ROUTES"
fi

# 路由结构守卫测试中的断言
ROUTE_TEST="$T/internal/app/httpserver/route_structure_test.go"
if [ -f "$ROUTE_TEST" ]; then
    perl -0pi -e 's{^[ \t]*`adproxytransport\.RegisterAdminRoutes\([^\n]*\n}{}m' "$ROUTE_TEST"
fi

# ---------------------------------------------------------------------------
# 3. 容器装配
# ---------------------------------------------------------------------------
CONTAINER="$T/internal/app/container/container.go"
if [ -f "$CONTAINER" ]; then
    perl -0pi -e 's{^[^\n]*modules/adproxy/application"\n}{}m' "$CONTAINER"
    perl -0pi -e 's{^[ \t]*AdProxyService[ \t]+\*adproxyapp\.Service\n}{}m' "$CONTAINER"
fi

SERVICES="$T/internal/app/container/services_application.go"
if [ -f "$SERVICES" ]; then
    perl -0pi -e 's{^[^\n]*modules/adproxy/(application|infrastructure/adgateway)"\n}{}mg' "$SERVICES"
    perl -0pi -e 's{^[ \t]*c\.AdProxyService = adproxyapp\.NewService\([^\n]*\n}{}m' "$SERVICES"
fi

# ---------------------------------------------------------------------------
# 4. RBAC 预置策略（只读审计员的两条广告权限）
# ---------------------------------------------------------------------------
BOOTSTRAP="$T/internal/authz/bootstrap.go"
if [ -f "$BOOTSTRAP" ]; then
    perl -0pi -e 's{^[ \t]*\{Object: "/admin/ads/[^\n]*\n}{}mg' "$BOOTSTRAP"
fi

# ---------------------------------------------------------------------------
# 5. 架构守卫里的历史路径清单
# ---------------------------------------------------------------------------
GUARD="$T/internal/architecture/complete_migration_guard_test.go"
if [ -f "$GUARD" ]; then
    perl -0pi -e 's{^[ \t]*"internal/modules/adproxy/[^\n]*\n}{}mg' "$GUARD"
fi

# ---------------------------------------------------------------------------
# 6. 前端 API 封装 / 类型
# ---------------------------------------------------------------------------
ADMIN_API="$T/frontend/admin/src/api/admin.ts"
if [ -f "$ADMIN_API" ]; then
    perl -0pi -e 's{\n[ \t]*// 广告代理\n(?:[ \t]*renderAdSlot:[\s\S]*?\),\n)?(?:[ \t]*reportAdImpression:[\s\S]*?\),\n)?}{}' "$ADMIN_API"
fi

TYPES="$T/frontend/admin/src/api/types.ts"
if [ -f "$TYPES" ]; then
    perl -0pi -e 's{// --- Ad Proxy ---\n[\s\S]*?export interface AdRenderResponse \{[\s\S]*?\n\}\n\n}{}' "$TYPES"
fi

# ---------------------------------------------------------------------------
# 7. 前端仪表盘挂载点（连带包裹 div 一起删，避免留下空容器）
# ---------------------------------------------------------------------------
DASHBOARD="$T/frontend/admin/src/views/Dashboard.vue"
if [ -f "$DASHBOARD" ]; then
    perl -0pi -e 's{^[ \t]*import DashboardAd from [^\n]*\n}{}m' "$DASHBOARD"
    perl -0pi -e 's{\n[ \t]*<div class="min-w-0">\n[ \t]*<DashboardAd slot-code="[^"]*"[^>]*/>\n[ \t]*</div>\n}{}g' "$DASHBOARD"
fi

# ---------------------------------------------------------------------------
# 8. i18n 文案（简中 / 繁中 / en 三份 admin.dashboard.ad 块）
# ---------------------------------------------------------------------------
I18N="$T/frontend/admin/src/i18n/index.ts"
if [ -f "$I18N" ]; then
    perl -0pi -e "s{\n[ \t]*ad: \{\n[ \t]*label: '[^']*',\n[ \t]*sponsored: '[^']*',\n[ \t]*showLess: '[^']*',\n[ \t]*showAll: '[^']*',\n[ \t]*\},\n}{\n}g" "$I18N"
fi

# ---------------------------------------------------------------------------
# 9. 残留断言：任何一处漏删都会让构建立刻失败，而不是静默留下死代码
# ---------------------------------------------------------------------------
if [ -d "$T/internal/modules/adproxy" ]; then die "internal/modules/adproxy still exists"; fi
if [ -f "$T/frontend/admin/src/components/admin/DashboardAd.vue" ]; then die "DashboardAd.vue still exists"; fi

LEFTOVER=$(grep -rn -E 'adproxy|AdProxy|/admin/ads|DashboardAd|renderAdSlot|reportAdImpression|AdRender(Slot|Item|Response)' \
    "$T/internal" "$T/frontend/admin/src" 2>/dev/null \
    | grep -v -E '\.(lock|patch)$' || true)
if [ -n "$LEFTOVER" ]; then
    echo "$LEFTOVER" >&2
    die "ad-related references remain (see above)"
fi

LEFTOVER_I18N=$(grep -rn 'dashboard\.ad\.' "$T/frontend/admin/src" 2>/dev/null || true)
if [ -n "$LEFTOVER_I18N" ]; then
    echo "$LEFTOVER_I18N" >&2
    die "admin.dashboard.ad i18n keys remain (see above)"
fi

# 保证相邻代码没被正则误删
grep -q 'dashboardtransport.RegisterAdminRoutes(authorized, adminDashboardHandler)' "$ROUTES" \
    || die "routes_admin.go lost the dashboard route registration"
grep -q '"/admin/dashboard/inventory-alerts"' "$BOOTSTRAP" \
    || die "bootstrap.go lost neighbouring dashboard policies"

echo "remove-ads: OK"
