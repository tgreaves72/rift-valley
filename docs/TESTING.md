# Testing record

This is an early-access project. Automated checks and native engine runs support the results below. They do not replace human difficulty tuning, physical-device testing or live-service verification.

## Recorded checks

On 2026-10-24, a separate export containing only the 213 public repository files passed all 38 Luau suites, the original-audio suite and compilation of all 32 production scripts. Python builders parsed and relative Markdown links resolved. This check did not use local archives, raw logs or bundled toolchain files as repository inputs.

The original 0.15.0 offline run passed 38 Luau suites and compiled all 32 production scripts. After connecting real pass IDs, the place, pass, startup, client and mastery interface checks passed again. A later focused run passed profiles, passes, client, training/progression, training interface, mastery interface and playtest metrics suites.

The configured source snapshot has SHA-256:

```text
a004aaf23a25bb4d9b0ae51226290539607d9f6f64bc9249397c893c1c045717
```

Native multiplayer run `15n` completed on 2026-10-24 UTC with three actual Studio clients and automated movement input:

| Map | Attempts | Full escapes | Captures |
| --- | ---: | ---: | ---: |
| Crystal Grove | 1 | 2 | 0 |
| Sunset Ruins | 1 | 1 | 1 |
| Neon Harbor | 2 | 1 | 3 |

The test required at least one complete five-course escape on every map. It verified shared physical-plate votes, client HUD initialization and replicated player roles/course transitions. Inputs used normal ability requests and native humanoid movement. The test copy substituted a sprint input attribute and documented VIP/aim fixtures; it preserved the production match script and Workspace geometry. This race-only group did not exercise the VIP ownership fixture.

The separate physics run passed all 24 catcher routes across three themes and five courses, plus all 24 individual planned parkour transfers. Each jump started from a planned takeoff edge with normal running velocity. This proves individual transfers, not a human completing the entire lap.

Passive observations recorded 74 catcher startups, all moving more than 0.5 studs within one second. All four configured music assets loaded and entered playback. The three chase tracks showed nonzero playback volume. These observations do not certify audible quality on speakers or published-game audio permissions.

The checked source, binary and portable result summary appear in [validation.json](validation.json). Raw application logs, absolute workstation paths and desktop screenshots remain outside the public repository.

## Limits and pending checks

- Live profile persistence after leaving and rejoining remains unverified.
- Real paid purchase testing was explicitly skipped. Simulated cancellation/ownership checks passed; the creator owning its own passes is not a genuine purchase test.
- Live analytics dashboard delivery remains unverified. Studio deliberately sends no live analytics events.
- Mobile/controller layouts have module checks; native device emulation and physical-device play remain incomplete.
- Three local clients do not establish 30-player performance. Background-window frame-rate samples do not represent foreground gameplay performance.
- One client logged a Roblox CoreScripts chat initialization error involving `CoreGuiChatConnections`. A live chat check remains necessary.
- No human multiplayer playtest or final balance sign-off has been recorded.

## Reproduce native checks

Generate an isolated multiplayer copy:

```powershell
python build/studio_multiplayer_place.py 15n --races-only
```

Open the generated place in Studio, choose Server & Clients and start three clients. The harness logs `[RiftMP]` results. The collector verifies source and geometry against the current local release before writing its report:

```powershell
python build/collect_multiplayer_results.py
```

Generate the navigation and parkour physics copy:

```powershell
python build/studio_test_place.py 15n
```

Open `dist/RiftValley-StudioTests15n.rbxlx` and use Run (F8). A completed successful run reports `[RiftEngine]` with `passed: 48` and `total: 48`. Test copies stay local and must never replace the published game.
