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

Patch `0018` adds `player-presence-history`. It reuses the existing 15-second
monitor loop to sample the official REST players endpoint, stores bounded
sessions and totals in SQLite KV, caps recovery accrual after outages, and
attaches history only to the live server save source.

Patch `0019` fixes `panel-patch-hot-update` release discovery on shared hosting
networks. It reads the repository's released and verified stable workspace from
`raw.githubusercontent.com` first, constructs deterministic Release asset URLs,
and only falls back to the GitHub REST API. It also accepts the deployment token
aliases used by the one-click launcher.
