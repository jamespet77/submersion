# App Performance — Phase 1 Findings

**Date:** 2026-06-24
**Spec:** docs/superpowers/specs/2026-06-24-app-performance-investigation-design.md
**Plan:** docs/superpowers/plans/2026-06-24-app-performance-phase1-measurement.md
**Mode:** profile, macOS

## Environment
- Flutter: 3.41.4 stable (framework ff37bef603, engine e4b8dca3f1)
- macOS: 26.5.1 (build 25F80)
- Mac: MacBook Pro (Mac17,8), **Apple M5 Pro**
- Display: Built-in Liquid Retina XDR, 3456x2234 Retina, ProMotion (up to 120 Hz)
- Frame budget: 8.3 ms @ 120 Hz / 16.7 ms @ 60 Hz — **confirm the actual budget line from the DevTools Frames chart** (Flutter macOS desktop may render at 60 Hz even on a ProMotion panel)
- Library shape (from the design spec): 37 dives, 40,933 profile samples (avg 1,106, max 3,644), 40,912 tank-pressure samples, 22 MB DB

## Scenario 1 — Cold start / load time
(filled by Task 2)

## Scenario 2 — First dive-details lag
(filled by Task 3)

## Scenario 3 — Background-sync stutter
(filled by Task 4)

## Avenue verdicts & Phase 2 ranking
(filled by Task 5)
