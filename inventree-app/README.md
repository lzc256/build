# InvenTree App Patches

This directory contains patches for the [InvenTree App](https://github.com/inventree/inventree-app) Flutter mobile application.

## Build

The GitHub Actions workflow `.github/workflows/inventree-app-build.yml` builds the Android APK every 2 days, checking for upstream updates.

### Manual Build

```bash
# Trigger via workflow_dispatch with optional ref
gh workflow run inventree-app-build.yml -f ref=v1.0.0
```

## Patches

Add patch directories here following the framework's convention:
- Each subdirectory is a named patch
- Contains `.patch` files (git patches) or `.sh` scripts
