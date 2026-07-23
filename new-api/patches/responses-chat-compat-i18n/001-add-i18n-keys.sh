#!/bin/bash
# Add Responses -> ChatCompletions i18n keys to web/default locale files.
# Uses string anchors (not line numbers) for cross-version compatibility.
set -e

TARGET_DIR="$1"
LOCALE_DIR="$TARGET_DIR/web/default/src/i18n/locales"

translation_for_locale() {
    case "$1" in
        en) printf '%s' 'Responses -> ChatCompletions Compatibility' ;;
        fr) printf '%s' 'Compatibilité Responses -> ChatCompletions' ;;
        ja) printf '%s' 'Responses -> ChatCompletions 互換' ;;
        ru) printf '%s' 'Совместимость Responses -> ChatCompletions' ;;
        vi) printf '%s' 'Tương thích Responses -> ChatCompletions' ;;
        zh) printf '%s' 'Responses -> ChatCompletions 兼容' ;;
        *) return 1 ;;
    esac
}

for locale in en fr ja ru vi zh; do
    FILE="$LOCALE_DIR/$locale.json"
    if [ ! -f "$FILE" ]; then
        echo "SKIP: $FILE not found"
        continue
    fi

    if grep -q '"Responses -> ChatCompletions Compatibility"' "$FILE"; then
        echo "SKIP: $locale already has the key"
        continue
    fi

    VALUE="$(translation_for_locale "$locale")"
    python3 - "$FILE" "$VALUE" <<'PY'
import json
import sys

filepath = sys.argv[1]
value = sys.argv[2]

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

anchor = '"ChatCompletions -> Responses Compatibility"'
idx = content.find(anchor)
if idx == -1:
    print(f'ERROR: anchor not found in {filepath}', file=sys.stderr)
    sys.exit(1)

line_end = content.find('\n', idx)
if line_end == -1:
    print(f'ERROR: malformed file {filepath}', file=sys.stderr)
    sys.exit(1)

new_line = '    "Responses -> ChatCompletions Compatibility": ' + json.dumps(value, ensure_ascii=False) + ',\n'
content = content[:line_end + 1] + new_line + content[line_end + 1:]

if filepath.endswith('/zh.json'):
    content = content.replace(
        '"ChatCompletions -> Responses Compatibility": "ChatCompletions -> 响应兼容"',
        '"ChatCompletions -> Responses Compatibility": "ChatCompletions -> Responses 兼容"',
    )

hint_anchor = '"Empty value will be saved as {}."'
hint_idx = content.find(hint_anchor)
if hint_idx != -1:
    hint_end = content.find('\n', hint_idx)
    if hint_end != -1:
        hints = [
            '    "Use model_patterns to match specific models by regex, e.g. [\\"^gpt-4o.*$\\"]. Leave empty to match all models.": "Use model_patterns to match specific models by regex, e.g. [\\"^gpt-4o.*$\\"]. Leave empty to match all models.",',
            '    "Use model_patterns to match specific models by regex, e.g. [\\"^deepseek-.*$\\", \\"^glm-.*$\\"]. Leave empty to match all models.": "Use model_patterns to match specific models by regex, e.g. [\\"^deepseek-.*$\\", \\"^glm-.*$\\"]. Leave empty to match all models.",',
        ]
        for hint in reversed(hints):
            content = content[:hint_end + 1] + hint + '\n' + content[hint_end + 1:]

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print(f'FIXED: {filepath}')
PY
done

echo "i18n keys added successfully!"
