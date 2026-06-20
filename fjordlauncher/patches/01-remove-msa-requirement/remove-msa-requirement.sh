#!/bin/bash
DESCRIPTION="Remove Microsoft account requirement for offline and authlib-injector accounts"

# Target file
FILE="$1/launcher/ui/pages/global/AccountListPage.cpp"

if [ ! -f "$FILE" ]; then
    echo "Error: File not found: $FILE"
    exit 1
fi

echo "Removing Microsoft account requirement from AccountListPage.cpp"

# Use perl for reliable multiline replacement
# Remove the check in on_actionAddAuthlibInjector_triggered
perl -i -0pe 's/    if \(!m_accounts->anyAccountIsValid\(\)\) \{\n        QMessageBox::warning\(this, tr\("Error"\),\n                             tr\("You must add a Microsoft account that owns Minecraft before you can add an account on a custom "\n                                "authentication server\."\n                                "<br><br>"\n                                "If you have lost your account you can contact Microsoft for support\."\)\);\n        return;\n    \}\n\n//gs' "$FILE"

# Remove the check in on_actionAddOffline_triggered
perl -i -0pe 's/    if \(!m_accounts->anyAccountIsValid\(\)\) \{\n        QMessageBox::warning\(this, tr\("Error"\),\n                             tr\("You must add a Microsoft account that owns Minecraft before you can add an offline account\."\n                                "<br><br>"\n                                "If you have lost your account you can contact Microsoft for support\."\)\);\n        return;\n    \}\n\n//gs' "$FILE"

echo "Patch applied successfully!"
