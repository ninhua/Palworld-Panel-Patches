# License notice

The patch files under `source/` modify `uitok/palworld-panel`, which is distributed under GNU GPL version 3.

The patch source, modified binary, and corresponding patched source archive produced by the build workflow are distributed under GPL-3.0.

The `base-custom-names` behavior was independently implemented for this patch line. No source code was copied from the feature-reference repository because its licensing status has not been confirmed.

The repository-level MIT license applies only to original tooling and documentation that are not derivative works of the GPL-covered upstream source.

The `host-save-migrator` user flow was designed with reference to the documented behavior of `66six11/PalworldHostSaveMigrator` (MIT). No Python, Tk, palsav, or Kraken source from that repository is copied into this patch. Execution uses the GPL-3.0-or-later Rust UID remapper and pinned source snapshots already present in `uitok/palworld-panel` v1.3.0.

The `global-inventory-browser` behavior was independently implemented after reviewing the public feature surface of `Jiaayu/palworld-panel`. No Jiaayu backend, frontend, assets, or generated data are copied. The implementation uses only the GPL-3.0 target project's existing save-index, localization, item-icon, base-name, and container-resolution facilities.
