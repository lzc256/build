#!/bin/bash
# Add Responses -> ChatCompletions i18n keys to web/default locale files.
# Uses string anchors (not line numbers) for cross-version compatibility.
set -e

TARGET_DIR="$1"
LOCALE_DIR="$TARGET_DIR/web/default/src/i18n/locales"

# Translation values for each locale
declare -A TRANSLATIONS
TRANSLATIONS["en"]="Responses -> ChatCompletions Compatibility"
TRANSLATIONS["fr"]="Compatibilité Responses -> ChatCompletions"
TRANSLATIONS["ja"]="Responses -> ChatCompletions 互換"
TRANSLATIONS["ru"]="Совместимость Responses -> ChatCompletions"
TRANSLATIONS["vi"]="Tương thích Responses -> ChatCompletions"
TRANSLATIONS["zh"]="Responses -> ChatCompletions 兼容"

for locale in en fr ja ru vi zh; do
    FILE="$LOCALE_DIR/$locale.json"
    if [ ! -f "$FILE" ]; then
        echo "SKIP: $FILE not found"
        continue
    fi

    # Check if key already exists
    if grep -q '"Responses -> ChatCompletions Compatibility"' "$FILE"; then
        echo "SKIP: $locale already has the key"
        continue
    fi

    # Insert new key after "ChatCompletions -> Responses Compatibility" line
    VALUE="${TRANSLATIONS[$locale]}"
    python3 -c "
import sys
filepath = sys.argv[1]
value = sys.argv[2]

with open(filepath, 'r') as f:
    content = f.read()

anchor = '\"ChatCompletions -> Responses Compatibility\"'
idx = content.find(anchor)
if idx == -1:
    print(f'ERROR: anchor not found in {filepath}', file=sys.stderr)
    sys.exit(1)

line_end = content.find('\n', idx)
if line_end == -1:
    sys.exit(1)

new_line = '    \"Responses -> ChatCompletions Compatibility\": ' + repr(value) + ',\n'
# repr adds single quotes for strings with special chars; fix to double quotes
new_line = new_line.replace(\"'\", '\"')

content = content[:line_end + 1] + new_line + content[line_end + 1:]

# For zh.json, also update existing translation
if 'zh.json' in filepath:
    content = content.replace(
        '\"ChatCompletions -> Responses Compatibility\": \"ChatCompletions -> 响应兼容\"',
        '\"ChatCompletions -> Responses Compatibility\": \"ChatCompletions -> Responses 兼容\"'
    )

# Add model_patterns hint keys after \"Empty value will be saved as {}.\"
hint_anchor = '\"Empty value will be saved as {}.\"'
hint_idx = content.find(hint_anchor)
if hint_idx != -1:
    hint_end = content.find('\n', hint_idx)
    if hint_end != -1:
        hints = [
            '    \"Use model_patterns to match specific models by regex, e.g. [\\\\\"^gpt-4o.*$\\\\\"]. Leave empty to match all models.\": \"Use model_patterns to match specific models by regex, e.g. [\\\\\"^gpt-4o.*$\\\\\"]. Leave empty to match all models.\",',
            '    \"Use model_patterns to match specific models by regex, e.g. [\\\\\"^deepseek-.*$\\\\\", \\\\\"^glm-.*$\\\\\"]. Leave empty to match all models.\": \"Use model_patterns to match specific models by regex, e.g. [\\\\\"^deepseek-.*$\\\\\", \\\\\"^glm-.*$\\\\\"]. Leave empty to match all models.\",',
        ]
        for hint in reversed(hints):
            content = content[:hint_end + 1] + hint + '\n' + content[hint_end + 1:]

with open(filepath, 'w') as f:
    f.write(content)
print(f'FIXED: {filepath}')
" "$FILE" "$VALUE"
done

echo "i18n keys added successfully!"
