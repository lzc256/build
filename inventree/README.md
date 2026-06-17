# InvenTree Docker Image

A minimal Docker image for [InvenTree](https://inventree.org/) - open-source inventory management system.

## What's Different from Official Image

| Component | Official | This Image |
|-----------|----------|------------|
| Database clients | postgresql-client, mariadb-client | Removed (SQLite only) |
| PDF generation | WeasyPrint + pango/cairo/poppler | Removed |
| Fonts | fonts-noto-cjk (~150MB), fonts-noto-core, fonts-terminus | Removed |
| LDAP auth | libldap2, django-auth-ldap, python-ldap | Removed |
| **Image size** | ~500MB | ~200-250MB |

## Limitations

- **No PDF reports**: WeasyPrint is removed, so PDF label/report generation won't work
- **No LDAP authentication**: LDAP/Active Directory integration is not available
- **No CJK fonts**: Chinese/Japanese/Korean text may not render correctly in any remaining font-dependent features
- **SQLite by default**: Designed for SQLite database; PostgreSQL/MySQL drivers still work but CLI tools removed

## Usage

### Quick Start (SQLite)

```bash
docker compose up -d
```

Access at http://localhost:8000

### Configuration

Edit `docker-compose.yml` to set:
- `INVENTREE_SECRET_KEY`: Required, set a random secret string
- `INVENTREE_ADMIN_USER/PASSWORD/EMAIL`: Optional, creates admin on first run

### With PostgreSQL/Redis

For production use with external database:

```bash
docker compose -f docker-compose.full.yml up -d
```

## Building

The image is built automatically via GitHub Actions when upstream InvenTree updates.

Build triggers:
- Schedule: Once daily
- Push: Changes to `inventree/` directory
- Manual: `workflow_dispatch`

## Files

| File | Purpose |
|------|---------|
| `patches/01-slim-packages/slim-packages.sh` | Removes system packages from Dockerfile |
| `patches/02-slim-requirements/slim-requirements.sh` | Removes Python packages |
| `docker-compose.yml` | SQLite-only deployment |
| `docker-compose.full.yml` | PostgreSQL + Redis deployment |

## Technical Details

### How It Works

1. Clone upstream InvenTree repository
2. Apply patch scripts to modify `contrib/container/Dockerfile` and `contrib/container/requirements.txt`
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
- `weasyprint`
- `django-auth-ldap`
- `python-ldap`

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