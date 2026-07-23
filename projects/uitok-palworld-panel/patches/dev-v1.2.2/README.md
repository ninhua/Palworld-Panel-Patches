# dev → v1.2.2 patch line

## Source lock

```text
repository: uitok/palworld-panel
ref: dev
commit: 5e3c0bce9d33091b3261f82b3e4da062fc35a8a1
target: v1.2.2
compatibility: source-alias, verified=false
```

## Patch 0.4.0-dev.1

This version contains four features:

```text
patch-info-api
base-custom-names
base-storage-browser
player-notes
```

### Patch information

```http
GET /api/patch/info
```

The response reports patch version `0.4.0-dev.1` and all feature identifiers.

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
- Supports search by localized container name, container type, localized item name, or internal item ID.
- Resolves the container map-object type into a localized display name when available.
- Shows bundled item WebP icons with an SVG fallback when an icon is missing.
- Groups occupied slots by container and shows slot, quantity, and durability when available.
- Displays stale-index warnings and retry handling.
- Resolves both directly owned base containers and map-object containers linked through the base container list.
- Does not mutate containers or save files.

### Player notes and tags

```http
PUT /api/players/{id}/annotation
Content-Type: application/json

{"note":"负责建筑规划","tags":["建筑师","活跃"]}
```

```http
DELETE /api/players/{id}/annotation
```

Behavior:

- Requires `players:write` permission.
- Stores notes and tags in the PalPanel SQLite KV table.
- Isolates annotations by save-source ID.
- Supports up to 500 Unicode characters in the note.
- Supports up to 8 tags, each limited to 24 Unicode characters.
- Adds note and tag search to the player list.
- Does not modify player `.sav` files.

## Patch sequence

```text
0001-add-patch-info-api.patch
0002-add-base-custom-names.patch
0003-add-base-storage-browser.patch
0004-fix-base-storage-container-resolution.patch
0005-enhance-base-storage-display.patch
0006-add-player-notes.patch
```

All patches are applied in lexical order and verified against `source/SHA256SUMS` before build.

## Build scope

The patch only rebuilds:

```text
bin/palpanel
```

It does not rebuild `sav-cli` or `palcalc-bridge`.
