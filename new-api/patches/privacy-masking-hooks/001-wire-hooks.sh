#!/bin/bash
# Modifies existing new-api files to wire in the privacy-masking files added
# by the privacy-masking .patch directory and the engine copied by
# privacy-masking-engine. No new files are created here.

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <new-api-source-dir>" >&2
    exit 1
fi

TARGET="$(cd "$1" && pwd)"

echo "========================================="
echo "Patch: privacy-masking hooks"
echo "Target: $TARGET"
echo "========================================="

# ------------------------------------------------------------- relay ------
ROUTER="$TARGET/router/relay-router.go"
if ! grep -q '"github.com/QuantumNous/new-api/privacy"' "$ROUTER"; then
    perl -0pi -e 's#(\t"github\.com/QuantumNous/new-api/middleware"\n)#$1\t"github.com/QuantumNous/new-api/privacy"\n#' "$ROUTER"
fi
if ! grep -q 'privacy.Middleware()' "$ROUTER"; then
    perl -0pi -e 's#(\trouter\.Use\(middleware\.DecompressRequestMiddleware\(\)\)\n)#$1\trouter.Use(privacy.Middleware())\n#' "$ROUTER"
fi
grep -q 'router.Use(privacy.Middleware())' "$ROUTER" || { echo "failed to add privacy relay hook" >&2; exit 1; }

# -------------------------------------------------------------- admin -----
API_ROUTER="$TARGET/router/api-router.go"
if ! grep -q '"github.com/QuantumNous/new-api/privacy"' "$API_ROUTER"; then
    perl -0pi -e 's#(\t"github\.com/QuantumNous/new-api/middleware"\n)#$1\t"github.com/QuantumNous/new-api/privacy"\n#' "$API_ROUTER"
fi
if ! grep -q 'privacy.RegisterAdminRoutes' "$API_ROUTER"; then
    perl -0pi -e 's#(\t\t\tadminRoute\.Use\(middleware\.AdminAuth\(\)\)\n)#$1\t\t\tprivacy.RegisterAdminRoutes(adminRoute)\n#' "$API_ROUTER"
fi
grep -q 'privacy.RegisterAdminRoutes' "$API_ROUTER" || { echo "failed to add privacy admin hook" >&2; exit 1; }

# ---------------------------------------------------------- jsplugin -------
UTILS="$TARGET/pkg/jsplugin/utils.go"
if ! grep -q '"github.com/QuantumNous/new-api/privacy"' "$UTILS"; then
    perl -0pi -e 's#(\t"github\.com/MoeForge/moejs"\n)#$1\t"github.com/QuantumNous/new-api/privacy"\n#' "$UTILS"
fi
if ! grep -q 'magpieMaskJSON' "$UTILS"; then
    perl -0pi -e 's#(\t\t"hasCapability": runtime\.Function\("hasCapability", 1, func\(r \*moejs\.Realm, _ moejs\.Value, args \[\]moejs\.Value\) \(moejs\.Value, error\) \{\n\t\t\tname, err := stringValue\(r, moejs\.Arg\(args, 0\)\)\n\t\t\tif err != nil \{\n\t\t\t\treturn moejs\.Undefined\(\), err\n\t\t\t\}\n\t\t\treturn moejs\.Bool\(HasCapability\(name\)\), nil\n\t\t\}\),\n)#$1\t\t"magpieMaskJSON": runtime.Function("magpieMaskJSON", 2, func(r *moejs.Realm, _ moejs.Value, args []moejs.Value) (moejs.Value, error) {\n\t\t\tbody, err := stringValue(r, moejs.Arg(args, 0))\n\t\t\tif err != nil {\n\t\t\t\treturn moejs.Undefined(), r.TypeError("utils.magpieMaskJSON body must be a string")\n\t\t\t}\n\t\t\tmeta, err := stringValue(r, moejs.Arg(args, 1))\n\t\t\tif err != nil {\n\t\t\t\treturn moejs.Undefined(), r.TypeError("utils.magpieMaskJSON metadata must be a string")\n\t\t\t}\n\t\t\tmasked, err := privacy.MaskJSONForJS([]byte(body), meta)\n\t\t\tif err != nil {\n\t\t\t\treturn moejs.Undefined(), err\n\t\t\t}\n\t\t\treturn moejs.String(masked), nil\n\t\t}),\n#' "$UTILS"
fi
if ! grep -q 'magpieMaskPatch' "$UTILS"; then
    perl -0pi -e 's#(\t\t\tmasked, err := privacy\.MaskJSONForJS\(\[\]byte\(body\), meta\)\n\t\t\tif err != nil \{\n\t\t\t\treturn moejs\.Undefined\(\), err\n\t\t\t\}\n\t\t\treturn moejs\.String\(masked\), nil\n\t\t\}\),\n)#$1\t\t"magpieMaskPatch": runtime.Function("magpieMaskPatch", 2, func(r *moejs.Realm, _ moejs.Value, args []moejs.Value) (moejs.Value, error) {\n\t\t\tbody, err := stringValue(r, moejs.Arg(args, 0))\n\t\t\tif err != nil {\n\t\t\t\treturn moejs.Undefined(), r.TypeError("utils.magpieMaskPatch body must be a string")\n\t\t\t}\n\t\t\tmeta, err := stringValue(r, moejs.Arg(args, 1))\n\t\t\tif err != nil {\n\t\t\t\treturn moejs.Undefined(), r.TypeError("utils.magpieMaskPatch metadata must be a string")\n\t\t\t}\n\t\t\tpatch, err := privacy.MaskPatchForJS([]byte(body), meta)\n\t\t\tif err != nil {\n\t\t\t\treturn moejs.Undefined(), err\n\t\t\t}\n\t\t\treturn moejs.String(patch), nil\n\t\t}),\n#' "$UTILS"
fi
grep -q 'magpieMaskJSON' "$UTILS" && grep -q 'magpieMaskPatch' "$UTILS" || { echo "failed to inject magpie host functions" >&2; exit 1; }

# --------------------------------------------------- upstream test list ---
TEST_FILE="$TARGET/plugins/builtin_plugins_test.go"
if [ -f "$TEST_FILE" ] && ! grep -q '"request-mask"' "$TEST_FILE"; then
    perl -0pi -e 's#(\t"request-redact":     \{"ingress", "egress", "reply"\},\n)#$1\t"request-mask":      {"ingress", "egress", "reply"},\n#' "$TEST_FILE"
fi

# ------------------------------------------------ astrlink guard deps ----
if ! grep -q 'github.com/clipperhouse/uax29' "$TARGET/go.mod"; then
    (cd "$TARGET" && go mod edit \
        -require=github.com/clipperhouse/stringish@v0.1.1 \
        -require=github.com/clipperhouse/uax29/v2@v2.5.0)
fi
SUM="$TARGET/go.sum"
if ! grep -q '^github.com/clipperhouse/stringish v0.1.1 ' "$SUM"; then
    printf '%s\n' \
        'github.com/clipperhouse/stringish v0.1.1 h1:+NSqMOr3GR6k1FdRhhnXrLfztGzuG+VuFDfatpWHKCs=' \
        'github.com/clipperhouse/stringish v0.1.1/go.mod h1:v/WhFtE1q0ovMta2+m+UbpZ+2/HEXNWYXQgCt4hdOzA=' >>"$SUM"
fi
if ! grep -q '^github.com/clipperhouse/uax29/v2 v2.5.0 ' "$SUM"; then
    printf '%s\n' \
        'github.com/clipperhouse/uax29/v2 v2.5.0 h1:x7T0T4eTHDONxFJsL94uKNKPHrclyFI0lm7+w94cO8U=' \
        'github.com/clipperhouse/uax29/v2 v2.5.0/go.mod h1:Wn1g7MK6OoeDT0vL+Q0SQLDz/KpfsVRgg6W7ihQeh4g=' >>"$SUM"
fi

# ------------------------------------------------------------- frontend ---
if [ -d "$TARGET/web/src" ]; then
    FRONT_SRC="$TARGET/web/src"
else
    FRONT_SRC="$TARGET/web/default/src"
fi

FORM="$FRONT_SRC/features/task-plugins/components/request-plugin-config-form.tsx"
if [ -f "$FORM" ]; then
    if ! grep -q 'privacy-model-settings' "$FORM"; then
        perl -0pi -e "s#(import \{ RequestPluginConfigField \} from './request-plugin-config-field'\n)#import { PrivacyModelSettings } from './privacy-model-settings'\n\$1#" "$FORM"
    fi
    if ! grep -q "props.pluginKey === 'request-mask'" "$FORM"; then
        perl -0pi -e "s#(<div className='divide-y rounded-xl border'>\n)#\$1      {props.pluginKey === 'request-mask' && (\n        <PrivacyModelSettings className='px-4 py-3.5' />\n      )}\n#" "$FORM"
    fi
    grep -q 'PrivacyModelSettings' "$FORM" || { echo "failed to add privacy model settings" >&2; exit 1; }
fi


REG="$FRONT_SRC/features/dashboard/section-registry.tsx"
if ! grep -q "id: 'privacy'" "$REG"; then
    perl -0pi -e "s#(\n\] as const)#\n  {\n    id: 'privacy',\n    titleKey: 'Privacy Masking',\n    adminOnly: true,\n    build: () => null,\n  },\$1#" "$REG"
fi
perl -0pi -e "s#new Set<string>\(\['users'\]\)#new Set<string>(['users', 'privacy'])#" "$REG"

IDX="$FRONT_SRC/features/dashboard/index.tsx"
if ! grep -q 'LazyPrivacyMasking' "$IDX"; then
    perl -0pi -e "s#(const LazyFlowCharts = lazy\(\(\) =>\n  import\('\./components/flow/flow-charts'\)\.then\(\(m\) => \(\{\n    default: m\.FlowCharts,\n  \}\)\)\n\))#\$1\nconst LazyPrivacyMasking = lazy(() =>\n  import('./components/privacy/privacy-masking').then((m) => ({\n    default: m.PrivacyMasking,\n  }))\n)\n#" "$IDX"
fi

if ! grep -q "  privacy: {" "$IDX"; then
    perl -0pi -e "s#(  users: \{\n    titleKey: 'User Analytics',\n  \},\n)#\$1  privacy: {\n    titleKey: 'Privacy Masking',\n  },\n#" "$IDX"
fi
perl -0pi -e "s#\(section\) => section !== 'overview' && \(section !== 'users' \|\| isAdmin\)#(section) =>\n          section !== 'overview' &&\n          section !== 'privacy' &&\n          (section !== 'users' || isAdmin)#" "$IDX"
if ! grep -q "activeSection === 'privacy'" "$IDX"; then
    perl -0pi -e "s#(        </div>\n      </SectionPageLayout.Content>)#          {activeSection === 'privacy' && isAdmin && (\n            <FadeIn>\n              <Suspense fallback={<ModelChartsFallback />}>\n                <LazyPrivacyMasking />\n              </Suspense>\n            </FadeIn>\n          )}\n\$1#" "$IDX"
fi

EN="$FRONT_SRC/i18n/locales/en.json"
if ! grep -q '"Privacy Masking"' "$EN"; then
    perl -0pi -e 's#("Previous page": "[^"]*",\n)#$1    "Privacy Masking": "Privacy Masking",\n#' "$EN"
fi
ZH="$FRONT_SRC/i18n/locales/zh.json"
if ! grep -q '"Privacy Masking"' "$ZH"; then
    perl -0pi -e 's#("Previous page": "[^"]*",\n)#$1    "Privacy Masking": "隐私脱敏看板",\n#' "$ZH"
fi

for spec in \
    "ja|プライバシーマスキング" \
    "ko|개인정보 마스킹" \
    "fr|Masquage de la confidentialité" \
    "ru|Маскировка конфиденциальности" \
    "vi|Che giấu quyền riêng tư"; do
    LOCALE="${spec%%|*}"
    TEXT="${spec#*|}"
    FILE="$FRONT_SRC/i18n/locales/$LOCALE.json"
    if [ -f "$FILE" ] && ! grep -q '"Privacy Masking"' "$FILE"; then
        TEXT="$TEXT" perl -0pi -e 'my $t = $ENV{TEXT}; s#("Previous page": "[^"]*",\n)#$1    "Privacy Masking": "$t",\n#' "$FILE"
    fi
done

SIDEBAR="$FRONT_SRC/hooks/use-sidebar-data.ts"
if [ -f "$SIDEBAR" ] && ! grep -q "'/dashboard/privacy'" "$SIDEBAR"; then
    perl -0pi -e "s#(          \{\n            title: t\('Request processing'\),\n            url: '/request-processing',\n            icon: Workflow,\n            requiredRole: ROLE.SUPER_ADMIN,\n          \},\n)#\$1          {\n            title: t('Privacy Masking'),\n            url: '/dashboard/privacy',\n            icon: ShieldCheck,\n            requiredRole: ROLE.ADMIN,\n          },\n#" "$SIDEBAR"
fi



echo "Applied privacy-masking hooks"
echo "========================================="
