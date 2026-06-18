# InvenTree Docker Image

A minimal Docker image for [InvenTree](https://inventree.org/) - open-source inventory management system.

## What's Different from Official Image

| Component | Official | This Image |
|-----------|----------|------------|
| Database clients | postgresql-client, mariadb-client | Removed (SQLite only) |
| PDF generation | WeasyPrint + pango/cairo/poppler | Removed |
| Fonts | fonts-noto-cjk (~150MB), fonts-noto-core, fonts-terminus | Removed |
| LDAP auth | libldap2, django-auth-ldap, python-ldap | Removed |
| PDF fonts/libs | fonttools (~27MB), pyphen | Removed (weasyprint deps) |
| AWS S3 storage | boto3, botocore (~30MB) | Removed (SLIM_NO_S3=1) |
| SAML auth | xmlsec, python3-saml (~12MB) | Removed (SLIM_NO_S3=1) |
| gRPC telemetry | grpcio, otel-grpc (~18MB) | Removed (SLIM_NO_S3=1) |

## Limitations

- **No PDF reports**: WeasyPrint is removed, so PDF label/report generation won't work
- **No LDAP authentication**: LDAP/Active Directory integration is not available
- **No S3 storage**: AWS S3 file storage not available (when SLIM_NO_S3=1)
- **No SAML authentication**: SAML SSO not available (when SLIM_NO_S3=1)
- **No CJK fonts**: Chinese/Japanese/Korean text may not render correctly
- **SQLite by default**: Designed for SQLite database; PostgreSQL drivers still work but CLI tools removed

## Usage

### Quick Start (SQLite)

```bash
docker compose up -d
```

Access at http://localhost:8000

### Configuration

Edit `docker-compose.yml` to set:
- `INVENTREE_SECRET_KEY`: Required, set a random secret string
- `INVENTREE_SITE_URL`: Required, your server URL
- `INVENTREE_AUTO_UPDATE`: Set `True` for auto migrations
- `INVENTREE_ADMIN_USER/PASSWORD/EMAIL`: Optional, creates admin on first run

### With PostgreSQL/Redis

```bash
docker compose -f docker-compose.full.yml up -d
```

## Building

The image is built automatically via GitHub Actions when upstream InvenTree updates.

Build triggers:
- Schedule: Once daily
- Push: Changes to `inventree/` directory
- Manual: `workflow_dispatch` (with `no_s3` option)

### SLIM_NO_S3 Option

The `SLIM_NO_S3` flag controls whether S3/SAML/gRPC dependencies are included:

| Flag | Image includes | Approx. size |
|------|---------------|-------------|
| `SLIM_NO_S3=0` | S3, SAML, gRPC | +60MB |
| `SLIM_NO_S3=1` (default) | Removed | smaller |

In CI, use the `no_s3` workflow input to control this.

## Files

| File | Purpose |
|------|---------|
| `patches/01-slim-packages/slim-packages.sh` | Removes system packages from Dockerfile |
| `patches/02-slim-requirements/slim-requirements.sh` | Removes Python packages (with SLIM_NO_S3 flag) |
| `patches/03-remove-weasyprint-code/remove-weasyprint.sh` | Patches Python source to remove weasyprint imports |
| `docker-compose.yml` | SQLite-only deployment |
| `docker-compose.full.yml` | PostgreSQL + Redis deployment |

## Technical Details

### How It Works

1. Clone upstream InvenTree repository
2. Apply patch scripts to modify Dockerfile, requirements, and source code
3. Build Docker image with `production` target
4. Push to GHCR

### Patches Applied

**01-slim-packages**: Modifies Dockerfile apt-get install lines:
- Removes: `postgresql-client mariadb-client`
- Removes: `weasyprint libpango-1.0-0 libcairo2 poppler-utils`
- Removes: `fonts-noto-cjk fonts-noto-core`
- Removes: `libldap2`
- Removes build deps: `libldap2-dev libsasl2-dev libmariadb-dev`

**02-slim-requirements**: Removes from requirements.txt:
- `weasyprint`, `fonttools`, `pyphen` (PDF generation chain)
- `django-auth-ldap`, `python-ldap` (LDAP)
- `mariadb`, `mysqlclient` (database clients)
- With `SLIM_NO_S3=1`: `boto3`, `botocore`, `xmlsec`, `python3-saml`, `grpcio`, `opentelemetry-exporter-otlp-proto-grpc`

**03-remove-weasyprint-code**: Patches Python source files:
- `report/models.py`: Remove weasyprint import, prevent sys.exit
- `report/fetcher.py`: Remove URLFetcher inheritance
- `plugin/builtin/labels/label_sheet.py`: Remove weasyprint import

## Image

```
ghcr.io/lzc256/build:inventree
ghcr.io/lzc256/build:inventree-<version>
```

## Verification

Check image size:
```bash
docker images ghcr.io/lzc256/build:inventree
```

Health check:
```bash
curl http://localhost:8000/api/
```