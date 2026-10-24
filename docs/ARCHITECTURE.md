# Architecture

Rift Valley uses Roblox's client-server model. The server decides game outcomes; clients present state and send requested actions.

## Server authority

`Game.server.luau` coordinates the lobby, 30-second vote queue, role assignment, five-course run and results. `WorldService` and `CourseService` manage lobby activities, map mechanics, supported arrivals and course transitions.

`CatcherNavigation` plans pursuit routes and handles jumps, blocked paths and recovery. `CaptureService` validates warned grabs and contact before converting runners. `CreatureRig` builds the native catcher model.

`ProfileStore` owns session leases and guarded profile updates. A failed load stays session-only and cannot overwrite a stored profile. Saves check the current session token before updating data. Studio skips live DataStore writes.

`PassService` checks Roblox ownership on join and after a reported purchase. It never treats a client claim or a saved profile flag as ownership. `VIPGearService` restricts coils and server-raycast blaster damage to the VIP activity arena.

`MasteryService`, `PracticeService`, `StyleService` and `LaunchService` manage progression, isolated practice, cosmetics, daily goals, training and private parkour replay data. `PlaytestService` records bounded gameplay and device-performance observations.

## Client presentation

`Controller.client.luau` handles input, responsive menus, match state and explicit purchase buttons. Other client scripts handle wind dash effects, creature animation, attack warnings, pickups, music, sky ambience, cosmetic presentation and parkour ghosts.

The client requests actions through remotes. It does not award coins, validate finishes, grant premium entitlements or decide blaster damage.

## Shared rules and assets

`Rules.luau` contains pure reward, progression, contact, movement and profile-sanitization rules. `Config.luau` defines courses, map choices and catalogs. `CreatureMotion` supplies procedural animation data. `PassIds` and `MusicIds` contain public Roblox asset IDs.

The Python world builder creates the native XML place and geometric artwork. Lune validates the serialized place and writes the binary. Native Studio harnesses operate in separate generated copies, with their input and ownership fixtures documented separately from production behavior.
