#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../.." && pwd)"
source_dir="${repo_root}/projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source"
patch="${source_dir}/0028-fix-global-inventory-sidebar-entry.patch"

[[ -f "${patch}" ]] || { echo "missing 0028 patch" >&2; exit 1; }

grep -Fq "diff --git a/frontend/src/components/layout/Sidebar.tsx b/frontend/src/components/layout/Sidebar.tsx" "${patch}"
grep -Fq "routeIDs: ['save-sources', 'global-inventory', 'pal-inventory', 'breeding', 'live-map']" "${patch}"

changed_files="$(grep '^diff --git a/' "${patch}" | sed -E 's#^diff --git a/([^ ]+) b/.*#\1#')"
[[ "${changed_files}" == "frontend/src/components/layout/Sidebar.tsx" ]] || {
  echo "0028 changed unexpected files: ${changed_files}" >&2
  exit 1
}

work="$(mktemp -d "${TMPDIR:-/tmp}/palpatch-sidebar.XXXXXX")"
trap 'rm -rf "${work}"' EXIT
mkdir -p "${work}/frontend/src/components/layout"
cat >"${work}/frontend/src/components/layout/Sidebar.tsx" <<'TSX'
import React from 'react';
import type { TranslationKey } from '../../i18n';

interface SidebarEntry {
  id: string;
  labelKey: TranslationKey;
  routeIDs: string[];
}

const sidebarGroups: Array<{ id: string; titleKey: TranslationKey; entries: SidebarEntry[] }> = [
  {
    id: 'world',
    titleKey: 'nav.worldGroup',
    entries: [
      { id: 'players-world', labelKey: 'nav.playersWorld', routeIDs: ['player-center', 'starter-gift', 'world-archive'] },
      { id: 'saves-breeding', labelKey: 'nav.saveTools', routeIDs: ['save-sources', 'pal-inventory', 'breeding', 'live-map'] },
      { id: 'mods', labelKey: 'nav.mods', routeIDs: ['mods'] },
    ],
  },
];
TSX
(
  cd "${work}"
  git init -q
  git apply --check "${patch}"
  git apply "${patch}"
)
grep -Fq "routeIDs: ['save-sources', 'global-inventory', 'pal-inventory', 'breeding', 'live-map']" "${work}/frontend/src/components/layout/Sidebar.tsx"
(
  cd "${source_dir}"
  expected="$(awk '$2 == "0028-fix-global-inventory-sidebar-entry.patch" {print $1}' SHA256SUMS)"
  actual="$(sha256sum 0028-fix-global-inventory-sidebar-entry.patch | awk '{print $1}')"
  [[ -n "${expected}" && "${expected}" == "${actual}" ]]
)

echo "Inventory Sidebar entry regression passed."
