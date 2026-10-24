RIFT VALLEY | NATIVE STUDIO TESTS

See docs/TESTING.md for current results, limitations and reproduction steps.
These harnesses run only in separate local test copies. They do not publish or
write live player profiles. Studio intentionally uses session-only progress.

THREE-CLIENT RACES
Run python build/studio_multiplayer_place.py 15n --races-only and open the
produced dist/RiftValley-MultiplayerTests15n.rbxlx in Studio. Choose Server &
Clients and start three clients. The harness logs tagged [RiftMP] JSON records.
Run python build/collect_multiplayer_results.py to collect local Studio logs
and verify production source and Workspace geometry against the release.
The input fixture uses an attribute for sprint polling and normal ability
requests. It preserves the production match script and geometry. Automated
movement input does not establish human difficulty or enjoyment.

NAVIGATION AND RUNNING JUMPS
Run python build/studio_test_place.py 15n, open the produced
dist/RiftValley-StudioTests15n.rbxlx and use Run (F8). This copy disables the
normal match loop and adds EngineMapCheck and EngineActors. Production
navigation, native geometry, mechanics and catcher rigs remain intact.
The harness checks 24 catcher routes across five courses and three themes,
plus 24 planned individual running jumps. Each jump starts at its planned
takeoff edge with normal running velocity. A passing run reports [RiftEngine]
with passed: 48 and total: 48. This does not prove a complete human parkour lap.

Test copies and raw logs stay local. Never publish a harness as the live game.
Live saves, genuine paid purchases, live analytics, physical devices, human
multiplayer balance and 30-player performance require separate checks.
