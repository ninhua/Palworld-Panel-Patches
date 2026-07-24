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
