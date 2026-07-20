# Continuity

## 2026-07-20T08:19:04-0700 [user/debugging]

- Petrel 3 troubleshooting exposed two separate tracks:
  - Issue [#645](https://github.com/submersion-app/submersion/issues/645): dive-computer identity/deletion. `Petrel 3` and `ssss` may be two database records for the same physical unit because platform Bluetooth identifiers can differ; compare serial number before changing records. Computer names are labels, and deletion currently clears links rather than merging records.
  - Issue [#652](https://github.com/submersion-app/submersion/issues/652): iCloud sync after local database reset/reimport while iPhone/iPad retain older databases and cursors. Hypothesis: multiple library generations produced stale/unstamped manifests and required Mac-authoritative rebuild plus iOS adoption.
- Mac was made authoritative by backing it up, rebuilding the iCloud backend from the Mac, then adopting the restored library on iPad and iPhone. Dives appeared after restarting apps. Current user workflow is Mac for dive-log management and iPhone for dive-computer downloads.
- PR [#646](https://github.com/submersion-app/submersion/pull/646) was renamed to “Keep epoch fence strict and report skipped sync peers.” Latest branch `fix/icloud-legacy-peer-sync-after-epoch` commit `ec817025b`.
- PR #646 now removes the unsafe timestamp-based legacy-manifest exception, strictly skips unstamped/different-epoch peers, and reports skipped peer IDs in `ChangesetReadResult`/`SyncResult`. Focused tests cover current, stale, and unstamped peers.
- PR validation: Dart formatting and `git diff --check` pass. Flutter test execution is blocked by pre-existing generated Drift/database compilation errors on this branch; do not attribute those errors to PR #646 without a clean baseline.
- GitHub cross-links: #645 references #652 and #646; #652 references #645 and #646; #646 references #652 and #645.
- Preserve unrelated worktree changes: `macos/Podfile.lock`, `macos/Runner.xcodeproj/project.pbxproj`, `packages/libdivecomputer_plugin/third_party/libdivecomputer`, and untracked `.local/`. Do not reset or clean them.

## Next likely work

- Review PR #646 feedback and CI; do not reintroduce timestamp-based epoch admission.
- For #652, consider a separate UX/safety PR: database-reset warning, reset/restore detection before publication, and guided “replace iCloud from this device” flow.
- For #645, verify whether `Petrel 3` and `ssss` have the same serial, then design a safe dive-computer alias/merge flow instead of deleting either record.
