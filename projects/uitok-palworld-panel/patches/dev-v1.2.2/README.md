# dev → v1.2.2 patch line

## Source lock

```text
repository: uitok/palworld-panel
ref: dev
commit: 5e3c0bce9d33091b3261f82b3e4da062fc35a8a1
target: v1.2.2
compatibility: source-alias, verified=false
```

## Patch 0.3.1-dev.1

This version contains three features:

```text
patch-info-api
base-custom-names
base-storage-browser
```

### Patch information

```http
GET /api/patch/info
```

The response reports patch version `0.3.1-dev.1` and all feature identifiers.

### Persistent custom base names

```http
PUT /api/bases/{id}/name
Content-Type: application/json

{"name":"北境制造中心"}
```

```http
DELETE /api/bases/{id}/name
```

Behavior:

- Requires `server:control` permission.
- Stores names in the PalPanel SQLite KV table.
- Does not modify `Level.sav` or any player save.
- Isolates names by active save-source ID.
- Returns `name`, `raw_name`, `custom_name`, and `has_custom_name` in base list/detail data.
- Allows base search to match the custom name.
- Adds edit and restore-original-name controls to the base page.
- Limits custom names to 64 Unicode characters.

### Read-only base storage browser

The base page now calls the existing read endpoint:

```http
GET /api/bases/{id}/storage
```

Behavior:

- Adds a “查看仓库” action to desktop rows and mobile cards.
- Shows container count, occupied slot count, and total item quantity.
- Supports search by localized item name or internal item ID.
- Groups occupied slots by container and shows slot, quantity, and durability when available.
- Displays stale-index warnings and retry handling.
- Resolves both directly owned base containers and map-object containers linked through the base container list.
- Does not mutate containers or save files.

## Patch sequence

```text
0001-add-patch-info-api.patch
0002-add-base-custom-names.patch
0003-add-base-storage-browser.patch
0004-fix-base-storage-container-resolution.patch
```

All patches are applied in lexical order and verified against `source/SHA256SUMS` before build.

## Build scope

The patch only rebuilds:

```text
bin/palpanel
```

It does not rebuild `sav-cli` or `palcalc-bridge`.
