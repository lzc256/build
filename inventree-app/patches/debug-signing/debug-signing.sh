#!/bin/bash
DESCRIPTION="Use debug signing for release build when key.properties is missing"

# Modify build.gradle to fallback to debug signing when key.properties doesn't exist
# Works on both macOS (sed -i '') and Linux (sed -i)
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' 's/signingConfig signingConfigs.release/signingConfig signingConfigs.debug/' "$1/android/app/build.gradle"
else
    sed -i 's/signingConfig signingConfigs.release/signingConfig signingConfigs.debug/' "$1/android/app/build.gradle"
fi