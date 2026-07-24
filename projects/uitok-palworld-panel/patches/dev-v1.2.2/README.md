# dev → v1.2.2 patch line

## Source lock

```text
repository: uitok/palworld-panel
ref: dev
commit: 5e3c0bce9d33091b3261f82b3e4da062fc35a8a1
target: v1.2.2
compatibility: source-alias, verified=false
```

## Patch 0.8.0-dev.1

This version contains eight features:

```text
patch-info-api
base-custom-names
base-storage-browser
player-notes
guild-detail-browser
base-worker-browser
base-feed-box-summary
insecure-endpoint-support
```

### Patch information

```http
GET /api/patch/info
```

The response reports patch version `0.8.0-dev.1` and all feature identifiers.


### HTTP and HTTPS endpoint compatibility

Behavior:

- Accepts HTTP or HTTPS for `PALPANEL_ASTRBOT_PLUGIN_URL` and the AstrBot plugin `panel_url`.
- Accepts HTTP or HTTPS WebDAV endpoints.
- Accepts HTTP or HTTPS OpenAI-compatible provider Base URLs.
- Accepts HTTP or HTTPS for configurable Steam API, community-server API, SteamCMD, and UE4SS endpoints.
- Accepts public HTTP or HTTPS remote Mod ZIP and Steam Workshop URLs.
- Retains validation for absolute URLs, supported schemes, embedded credentials, WebDAV path traversal, public Mod download addresses, redirects, and download size limits.
- Does not silently rewrite a configured protocol.
- Warns that HTTP carries credentials and payload data without transport encryption.

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

### Guild detail browser

```http
GET /api/guilds/{id}
```

Behavior:

- Adds detail actions to desktop rows and mobile guild cards.
- Shows the guild owner, member online state, level, and last-online time.
- Reuses save-source-scoped player notes and tags in the member view.
- Resolves both explicit guild base IDs and bases linked by guild ID.
- Shows custom base names, coordinates, structure counts, and worker counts.
- Reads save-index and PalPanel metadata only; no save mutation is performed.

### Read-only base worker browser

```http
GET /api/bases/{id}/workers
```

Behavior:

- Adds worker-list actions to desktop base rows and mobile base cards.
- Merges each base worker with the indexed Pal record by instance ID when available.
- Shows localized species name, nickname, level, gender, rank, status, expedition state, and passive traits.
- Shows total workers, average level, maximum level, named-worker count, and distinct species count.
- Supports search by nickname, species, character ID, instance ID, or passive trait.
- Does not invent hunger, SAN, work suitability, or other fields absent from the locked save index.
- Reads save-index data only and does not mutate Pal or base save data.


### Read-only base feed-box summary

```http
GET /api/bases/{id}/feed-boxes
```

Behavior:

- Adds a feed-box action to desktop base rows and mobile base cards.
- Recognizes normal feed boxes and refrigerated feed boxes while excluding generic chests and refrigerators.
- Aggregates identical items across feed boxes and reports total quantity and box distribution.
- Shows feed-box count, empty-box count, occupied slots, distinct item types, and total item quantity.
- Keeps per-box slot details and bundled item icons.
- Supports search by item name, item ID, feed-box name, feed-box type, or container ID.
- Does not infer spoilage, nutrition, freshness, or other fields absent from the locked save index.
- Reads save-index data only and does not mutate containers or save files.

## Patch sequence

```text
0001-add-patch-info-api.patch
0002-add-base-custom-names.patch
0003-add-base-storage-browser.patch
0004-fix-base-storage-container-resolution.patch
0005-enhance-base-storage-display.patch
0006-add-player-notes.patch
0007-add-guild-detail-browser.patch
0008-add-base-worker-browser.patch
0009-add-base-feed-box-summary.patch
0010-fix-missing-base-worker-handler.patch
0011-allow-http-service-endpoints.patch
```

All patches are applied in lexical order and verified against `source/SHA256SUMS` before build.

`0010` is a corrective source patch that restores the base-worker handler and its tests omitted from the generated `0008` patch. It does not change patch version or feature identifiers.

`0011` adds the top-level `insecure-endpoint-support` capability and relaxes HTTPS-only endpoint rules to HTTP/HTTPS compatibility for AstrBot, WebDAV, AI provider, configured upstream/download endpoints, and public remote Mod ZIP imports. It changes patch version to `0.8.0-dev.1`.

## Build scope

The patch only rebuilds:

```text
bin/palpanel
```

It does not rebuild `sav-cli` or `palcalc-bridge`.
