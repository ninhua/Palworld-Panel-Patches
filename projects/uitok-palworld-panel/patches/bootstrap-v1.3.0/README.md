# PalPanel v1.3.0 bootstrap track

This is the immutable, self-contained stable maintenance input for v1.3.0.

It owns its own `source/`, `build/`, licenses and manifest. Migration results
belong in `candidate-v1.3.0`; blocked candidate branches and Draft PRs must not
modify this bootstrap directory.

Compatibility remains `verified=false` until the official v1.3.0 source passes
patch migration, clean-room merged-patch verification, full tests, Linux amd64
build and `/api/patch/info` smoke validation.

Patch `0014` adds the `panel-patch-hot-update` feature. It uses the existing
PalPanel job queue, accepts only exact and verified stable releases for the
current target version, verifies release and binary checksums, performs an
atomic binary replacement, and restarts the Linux process through `exec` while
retaining a verified rollback backup.

Patch `0015` adds the `audit-log-response-display` feature. It exposes the
existing audit `message` response summary in desktop tables and mobile cards
without storing raw response bodies or additional sensitive data.

Patch `0016` restores the OpenAPI contract for the three patch-update routes so
the upstream route-contract test passes in clean-room verification.

Patch `0017` extends `audit-log-response-display` with a click-through response
detail dialog for desktop rows and mobile cards. It displays the complete
already-redacted audit message and record metadata, pretty-prints JSON, supports keyboard controls
and copying on secure or HTTP pages, and does not collect raw HTTP bodies.

Patch `0018` adds the required `player-presence-history` feature. Its four previously conflicting source sections are regenerated against the cumulative v1.3.0 context and must apply through standard `git apply`; no patch-name-specific adapter is used. It reuses the existing 15-second
monitor loop to sample the official REST players endpoint, stores bounded
sessions and totals in SQLite KV, caps recovery accrual after outages, and
attaches history only to the live server save source.

Patch `0019` fixes `panel-patch-hot-update` release discovery on shared hosting
networks. It reads the repository's released and verified stable workspace from
`raw.githubusercontent.com` first, constructs deterministic Release asset URLs,
and only falls back to the GitHub REST API. It also accepts the deployment token
aliases used by the one-click launcher.

Patch `0020` renders the audit response detail dialog through a React portal
attached to `document.body`. This keeps the fixed overlay outside `#app-main`'s
scroll, isolation and page-enter transform context, preventing the visible
empty-frame failure while preserving response metadata, formatting and copy
behavior.


Patch `0021` replaces generic audit success markers with bounded, recursively
redacted structured response details. Standard API helpers record their actual
`data` or `error` payload; direct JSON responses are captured as a compatibility
fallback. Sensitive keys and Bearer tokens are redacted before the existing
`audit_logs.message` field is written, and the final JSON is capped at 32 KiB.

## 0022 host-save-migrator

- 基于上游已固定源码的 `tools/palworld-uid-remap`，不引入 Python/Tk 运行时。
- 对受管导入存档执行 SteamID64 主机 UID 迁移。
- 使用现有 `/save-sources/import/inspect` 与 `/save-sources/import` 的 JSON 分流，保持 API 路径集合不变。
- 输出注册为新的 `kind=import` 存档源；源目录只读。
- 当前拒绝目标 UID 已存在的存档。
- helper 随 Release overlay 分发，但不列为安装前必须已存在的 manifest 目标；完整 overlay 安装会复制它。若旧部署或热更新只替换 `palpanel`，面板会从同版本 Release 直链包自举 helper，并校验构建时嵌入的 SHA-256。
- 离线环境可用 `PALPANEL_UID_REMAPPER_BIN` 指定预装 helper；镜像环境可用 `PALPANEL_UID_REMAPPER_PACKAGE_URL` 覆盖自举包地址。
