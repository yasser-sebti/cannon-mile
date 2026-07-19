# Cannon Mile

Cannon Mile is a landscape Flutter and Flame game prototype. It currently
launches through the complete production-style startup path and then displays
a layered player tank with Continuous and Boss Fight test modes. Both modes
follow the Windows mouse horizontally with a smooth heavy arrival and aim the
cannon at the pointer. Viewport-edge boost now eases across the outer side band
instead of switching on at the tank boundary; the absolute edge still requests
maximum speed only after the tank is already moving safely. A timestamped
cursor swipe inside that band can request a temporary 70% dodge boost from a
standstill without bypassing acceleration, arrival, or the speed-level cap.
Continuous keeps a persistent, amplified travel animation
while Boss Fight can settle completely still. Its main track keeps a visible
forward idle crawl in Continuous mode with a stronger idle cadence: slow
backing retains the forward frame
order at slightly reduced cadence, while fast backing reverses and boosts the
track sequence. A stronger high-speed cadence cap keeps edge-to-edge travel
readable without changing the round-wheel logic. Boss Fight settles onto one exact track pose so partially
blended wheel frames never remain visible after stopping. Round-wheel motion
remains independently speed-responsive. The
cannon mount follows a shallow upside-down U arc, and high-quality filtered
sprites keep the layered artwork smooth. Holding the primary mouse button plays
a fast four-pose muzzle flash rendered from 16 cached composites with a lighter
Gaussian halo, three tapered additive speed-lens streaks, and randomized
horizontal mirror, plays the
gunfire sound matching the selected bullet level with individually balanced
volume and subtle randomized `0.95x` to `1.05x` playback speed, then launches a
directional projectile. Alpha-aware swept collision resolves the first visible
projectile-core pixel against the aircraft silhouette, giving scout planes six
health and bullet levels one through six matching damage. Surviving planes use
a vivid 48–65% pure-red overlay that fades over 100 ms; every hit plays a compact,
pre-glowed 70 ms downward ten-frame impact and 12–16 orange physics particles.
A lethal hit replaces the plane with a pooled six-frame explosion with
pre-baked color-derived glow. Smoke immediately animates and fades behind it.
Fast smoke chunks spread and decay while a second delayed group fans upward in
an inverted-triangle plume and lingers before shrinking away. Fire rate progresses
evenly from 5.376 to 7.4 shots per second, bullet artwork has six test levels,
and spread levels two through five use substantial 10-degree spacing.
Projectile speed is a fixed 1,440 virtual pixels per second. A separate
six-level tank-speed control ranges evenly from 600 to the reduced 720
virtual pixels per second. The complete tank visual hierarchy renders at 70%
of its authored size; muzzle effects inherit that group scale and detached
projectiles receive the same scale explicitly. An optional test spawner sends
two-to-four scout planes from either side with continuous short wave gaps, burst
spacing, `280–700` speed, and safe upper-screen altitude lanes. Twenty pooled
planes prevent recurring spawn allocation, while predictive lane reservations
keep same-direction aircraft at least 1.5 plane widths apart. Destroyed planes
request a replacement after 60 ms. Active planes periodically drop pooled,
downward-facing triangle missiles that curve under gravity without dealing
damage. Ground contact plays a ten-frame burst and delayed five-frame smoke
above the tank plus one of three non-repeating sounds at 1.715% volume; Continuous
mode carries both visuals left with the simulated ground.
Projectiles use a
96-instance pool with cached paint and spread data. Every trigger also ejects
one tiny level-matched shell from the cannon's local-right port. Twenty-four
pooled shells use gravity, rotation, two exact ground-edge bounces, a short
skid, and fade-out cleanup without firing-time component allocation. In
Continuous mode, casings visibly eject right before an opposing map wind fades
in near the ground. That wind strengthens across each bounce and smoothly
reaches full ground speed during the skid, while Boss Fight retains ordinary
shell physics.
The first casing-to-ground contact plays one of four subtly pitch-varied drop
sounds. Selection never repeats the same clip twice, and a shared 180 ms gate
plus bounded voices prevents impact-audio buildup.

The repository contains the runtime architecture, loading system, responsive
stage, platform setup, lifecycle handling, reusable button behavior, tests,
development tools, and the first movement, animation, firing, and plane-damage
prototype. Enemy attacks, player health, scoring, and the complete combat loop
are not implemented yet.

See [FUTURE_PLANS.md](FUTURE_PLANS.md) for the gameplay direction, development
milestones, release gates, and originality requirements.

See [ABOUT_GAME.md](ABOUT_GAME.md) for a short description of the intended
game.

## Current Runtime

The application starts in this order:

```text
Android or Windows native launcher
    -> lib/main.dart
    -> platform and display configuration
    -> CannonMileApp
    -> GameShell
        + BootOverlay
        |   -> branding image
        |   -> game initialization
        |   -> first interface frame
        |
        + VirtualStage
            + GameWidget<CannonMileGame>
                -> CannonMileWorld
                    -> TankComponent
```

`GameShell` mounts the Flame game when the loading phase becomes visible. The
animated loading overlay reports the real image, audio, component-pool, and
two-frame renderer warm-up stages. The game remains covered until every stage
finishes, then the overlay fades to reveal the mouse-controlled prototype.

## Architecture at a Glance

| Area | Primary owner | Responsibility |
| --- | --- | --- |
| Application startup | `lib/main.dart` | Initializes Flutter, configures the platform, and creates the app |
| Shared configuration | `lib/app/` | Identity, colors, design size, timings, desktop preview, and platform setup |
| Loading pipeline | `lib/boot/` | Ordered boot tasks, progress reporting, timeouts, and loading presentation |
| Game simulation | `lib/game/` | Flame game instance, world, components, systems, managers, and game modes |
| Flutter interface | `lib/ui/` | Shell, responsive stage, overlays, pages, and reusable widgets |
| Native integration | `android/`, `windows/` | Application identity, splash, fullscreen behavior, refresh rate, and window setup |
| Asset maintenance | `assets/`, `tool/` | Branding and optional asset-category manifest synchronization |
| Verification | `test/` | Boot, lifecycle, responsive layout, assets, and widget behavior |

The main architectural boundary is simple:

- Flame owns the live game world and simulation.
- Flutter owns application chrome, loading, menus, pages, and semantic overlays.
- `GameShell` owns the relationship between those two layers.

## Application Layer

### `lib/main.dart`

The entry point:

1. Initializes Flutter bindings.
2. Applies the landscape and platform display configuration.
3. Parses optional Windows preview arguments.
4. Starts `CannonMileApp`.
5. Builds `GameShell` inside a dark, borderless Material application.

No game state should be added to `main.dart`.

### `lib/app/app_config.dart`

`AppConfig` is the central location for stable application-wide values:

- Product title.
- Orange Hat Boy branding asset path.
- The `1920 x 1080` virtual design size.
- Background, progress, and text colors.
- Production loading animation timings.

Put global presentation constants here only when they are truly shared by the
whole application. Feature-specific constants should remain with their feature.

### `lib/app/platform_bootstrap.dart`

This file configures platform behavior before the app is displayed:

- Landscape-left and landscape-right orientations.
- Immersive Android system UI.
- A guarded request for the highest supported Android refresh rate.

Refresh-rate activation is best-effort. A plugin or device failure is logged
but is not allowed to stop the game from launching.

### `lib/app/desktop_preview.dart`

Windows development builds accept:

```text
--preview-width
--preview-height
--preview-scale
```

These arguments simulate a target logical viewport inside the desktop window.
They are development aids and do not change the game's virtual coordinate
system.

## Game Layer

### `CannonMileGame`

`lib/game/cannon_mile_game.dart` defines:

```dart
class CannonMileGame extends FlameGame<CannonMileWorld>
```

The generic type tells Flame that this game owns a `CannonMileWorld`. This
provides a typed world throughout the game instead of relying on Flame's base
`World` type.

`CannonMileGame` currently:

- Creates the one `CannonMileWorld` instance.
- Draws the solid application background.
- Converts Windows mouse-hover coordinates into world coordinates.
- Uses a top-left camera coordinate system matching the virtual stage.
- Exposes an `initialized` future.
- Completes that future after the game, world, tank sprites, and tank layers
  finish loading.
- Reports initialization errors to the boot system.

The game class should remain the high-level coordinator. Individual enemies,
vehicles, projectiles, effects, and terrain should not be implemented directly
inside it.

### `CannonMileWorld`

`lib/game/cannon_mile_world.dart` is the root of the gameplay scene. It owns one
`TankComponent`, places it near the bottom of the responsive stage, forwards
the current pointer target, movement mode, held trigger, fire-rate,
bullet-artwork, spread, and tank-speed levels, and keeps the tank
inside the visible width.

Current and future world objects belong below this world:

```text
CannonMileWorld
    + TankComponent
        + persistent directional four-frame track interpolation
        + three speed-responsive bouncing round wheels
        + independently aimed cannon with an arched mount path
            + four-pose additive muzzle-flash effect
        + anchored shaking base
    + pooled bullet projectiles with swept plane collision and level damage
    + pooled bullet shells with gravity, bounce, rotation, and fade-out
    + pooled downward hit effects and orange physics particles
    + six-health pooled scout planes with red hit flashes
    + terrain
    + pickups
    + gameplay effects
```

The world is the correct owner for objects that participate in the simulation,
camera space, collision, or gameplay update loop.

### Game Folders

The folders establish boundaries for current and future work:

```text
lib/game/
|-- components/   Flame components such as vehicles, enemies, and projectiles
|-- managers/     Long-lived services such as audio, saves, or progression
|-- modes/        Rule sets and mode-specific orchestration
|-- systems/      Spawning, combat, collision, difficulty, and other processors
|-- cannon_mile_game.dart
`-- cannon_mile_world.dart
```

Use these folders according to responsibility:

- A visible or simulated world object belongs in `components/`.
- Logic operating across many components belongs in `systems/`.
- A long-lived service with application or session scope belongs in `managers/`.
- A complete rule set or play variant belongs in `modes/`.

Do not place gameplay state in Flutter widgets. Widgets can present state, but
the authoritative state should remain in the game layer.

## Flutter UI Layer

### `GameShell`

`lib/ui/stage/game_shell.dart` is the runtime composition root. It owns:

- The single `CannonMileGame` instance.
- The Flame `GameWidget`.
- The responsive `VirtualStage`.
- The startup `BootOverlay`.
- Six temporary plane-spawn, movement, tank-speed, fire-rate, bullet-artwork,
  and spread testing overlays.
- Primary-mouse trigger input and its lifecycle-safe cancellation.
- Application lifecycle observation.

The shell pauses Flame when the application becomes inactive, hidden, paused,
or detached. It resumes Flame and restores immersive Android UI when the
application returns.

This is the correct location for application-level overlays that must be
coordinated with the game. It should not become a gameplay controller.

### `VirtualStage`

`lib/ui/stage/virtual_stage.dart` converts the physical viewport into the
game's virtual coordinate space.

The base stage is `1920 x 1080`. Its scale is calculated from the smaller of
the available width and height ratios. When the physical screen is wider or
taller than 16:9, the virtual stage expands on that axis instead of stretching
or cropping the design.

Examples:

| Physical shape | Virtual behavior |
| --- | --- |
| 16:9 | Uses the base `1920 x 1080` stage |
| Ultrawide | Keeps the same height and exposes additional virtual width |
| Taller landscape display | Keeps the same width and exposes additional virtual height |
| Display with cutouts | Converts physical safe-area padding into virtual-stage padding |

`StageMetricsScope` exposes the calculated scale, virtual size, and safe
padding to descendant Flutter widgets. New menus and HUD elements should use
these metrics instead of assuming a particular physical resolution.

### Overlays and Pages

After loading, six safe-area-aware Flutter buttons toggle plane spawning and
Continuous/Boss Fight movement, and cycle tank speed, fire rate, bullet artwork,
and spread.
The buttons intercept their own clicks, while the Flame surface receives
primary-mouse hold for firing and hover/drag motion for aiming and movement. The
tank and bullets remain rendered by Flame so all behaviors share the same
virtual-stage coordinate system.

Future UI belongs in:

```text
lib/ui/
|-- overlays/   HUD, pause, results, notifications, and game-adjacent UI
|-- pages/      Full application pages such as settings, credits, or privacy
|-- stage/      Game surface composition and responsive stage calculations
`-- widgets/    Reusable interface building blocks
```

Use a Flame component for objects living in the game world. Use a Flutter
overlay for menus, text-heavy interfaces, accessibility, and application pages.

### `RaisedPressable`

`lib/ui/widgets/raised_pressable.dart` is retained as reusable interface
infrastructure. It provides:

- Animated face and shadow depth.
- Press translation.
- Optional platform feedback.
- A delayed callback synchronized with the press animation.
- Disabled-state handling.
- Safe cancellation and disposal.

All six prototype testing buttons use this behavior. Future buttons should compose
their visual style around it rather than duplicating press animation logic.

## Loading Architecture

`BootOverlay` owns the launch presentation, while `BootController` owns task
execution.

The production visual sequence is:

1. Pop the logo from 78% to 100% over 420 ms with `easeOutBack`.
2. Wait 500 ms before showing loading details.
3. Display the orange progress bar, percentage, and current task.
4. Hold the completed state for 300 ms.
5. Fade the loading overlay out over 800 ms.

The default boot pipeline resolves the Orange Hat Boy logo, decodes all 68
gameplay images, preloads gunfire, casing-impact, and explosion audio, bakes 64 track-morph samples, six
projectile brightness sprites, and 16 complete muzzle frames, creates the
projectile, shell, aircraft, missile, ground-impact, explosion, smoke, and particle pools, builds immutable plane
and projectile alpha masks, pre-bakes ten glowing impact frames, and renders
two covered warm-up frames.
Gameplay uses the baked results without runtime Gaussian filters, effect blend
layers, or bullet color filters.

Custom injected boot tasks retain a 10-second fail-soft timeout. The
authoritative game preload is always awaited after those tasks, so the overlay
cannot reveal partially decoded or unwarmed gameplay.

`BootController.run()` is deduplicated. Multiple calls during startup share the
same future and do not execute the task list more than once.

Add a new preload unit only when something must be ready before the first usable
screen. Optional content should still be loaded later by the feature that owns
it.

## Assets

The active assets are:

```text
assets/branding/orange_hat_boy_logo.webp
assets/effects/
|-- bullet1.webp
|-- bullet2.webp
|-- bullet3.webp
|-- bullet4.webp
|-- bullet5.webp
|-- bullethit1.webp through bullethit10.webp
|-- bulletshell1.webp
|-- bulletshell2.webp
|-- bulletshell3.webp
|-- bulletshell4.webp
|-- explosion1.webp through explosion6.webp
|-- fire1.webp
|-- fire2_1.webp
|-- fire3_1.webp
|-- fire4_1.webp
|-- ground-hit1.webp through ground-hit10.webp
|-- ground-hit-smoke1.webp through ground-hit-smoke5.webp
|-- particle1.webp through particle3.webp
|-- smoke-particle1.webp through smoke-particle7.webp
`-- smoke1.webp through smoke6.webp
assets/sounds/
|-- bomb-explosion1.wav through bomb-explosion3.wav
|-- bulletdrop1.wav through bulletdrop4.wav
|-- gunfire1.wav
|-- gunfire2.wav
|-- gunfire3.wav
|-- gunfire4.wav
|-- gunfire5.wav
|-- gunfire6.wav
`-- metal-hit1.wav through metal-hit3.wav
assets/tank skins/default-skin/
|-- base-tank.webp
|-- tank-canon.webp
|-- wheel-rounded.webp
|-- wheel1.webp
|-- wheel2.webp
|-- wheel3.webp
`-- wheel4.webp
```

The branding image is used by the Flutter loading overlay and as the source for
native launcher icons. The tank files form the first game-specific skin. The
fire files form the fast scaled muzzle sequence, while the five bullet files
retain their native canvases and glow padding. The four casing files map to
bullet levels `1–2`, `3–4`, `5`, and `6`, rendering at heights from 9 through
13.5 virtual pixels. Higher levels apply restrained
render scales so the large source canvases do not dominate the screen, with
small additional reductions on levels two through four. The
six-level placeholder uses `bullet5.webp` for both levels five and six until a
sixth sprite is supplied. Levels one through four receive RGB-only brightness
multipliers of 74%, 77%, 80%, and 83%, baked without changing alpha or modifying
their source artwork. Each bullet level selects its matching `gunfire1.wav` through
`gunfire6.wav` sound once per shot, including spread shots. Every playback uses
a uniformly randomized `0.95x` to `1.05x` speed for subtle pitch and timing
variation. Gunfire 1 remains at 15.925% volume; gunfire 2 uses 14.49175%,
gunfire 3 uses 20.7025%, gunfire 4 uses 18.63225%, and gunfire 5 and 6 use
10.35125%. Windows pre-attenuates the WAV data and prepares a
fixed reusable voice pool during loading. A fixed command ring and dedicated
audio worker keep reset and playback calls off Flutter's render thread while
eliminating per-shot sample copies, volume loops, device creation, and unbounded
long-tail overlap. Other platforms
preload an equivalent bounded pool.
The four bullet-drop files share the same preloaded audio path at 21% volume.
Their randomized selection excludes the previously played clip, while a
simulation-time cooldown and bounded voice count prevent dense shell landings
from stacking long audio tails.
The three bomb-explosion files play on missile-ground contact at 1.715% volume with
subtle `0.95x`–`1.05x` pitch variation and no immediate clip repetition. Eight
preloaded voices per clip share the same non-blocking worker queue as gunfire.
A saturated variation spills into another available clip instead of cutting
off an active explosion tail.
Every confirmed projectile-plane collision also selects one of three metal-hit
clips without repeating the previous clip. These impacts play at 4.2% volume
with independently randomized `0.90x`–`1.10x` speed. Eight pre-created voices
per clip provide 24 overlapping impacts; a saturated variation spills into
another available clip instead of restarting, delaying, or muting the hit.
Ground explosions use the same 24-voice spillover strategy, and the native
audio command ring holds 256 pending events.
The ten bullet-hit files are bottom-center aligned into cached orange-glow
composites and play downward from the exact visible contact pixel over 70 ms.
Each impact uses a seeded triangular visual scale from 24% to 32% of authored
size. The three white particle sources are recolored amber/orange at runtime,
rendered at 14–21 virtual pixels high, and reused through a 256-instance physics
pool, with 12–16 particles emitted per contact. Scout planes reset to six
health when activated; projectile levels deal one through six damage using
precomputed alpha-128 core boundaries against an alpha-64 aircraft mask.
Lethal damage activates one of 12 pooled six-frame explosions at the aircraft
center. Each frame receives a large source-color outer glow plus a tighter core
glow during loading, so runtime rendering remains one image draw without live
blur. Frame dimensions
interpolate smoothly and the effect fades back into its pool after 228 ms. A
six-frame smoke layer begins immediately behind the explosion, drifts upward,
and follows the same compact animation-and-fade shape over 360 ms. Fourteen to
eighteen physics smoke chunks use all seven supplied particle artworks. Half
form the immediate burst; the other half activate later, rise more slowly, and
fade over a longer lifetime. Both profiles rotate, resize, and return to a
256-instance pool.
Aircraft attacks use 64 pooled triangle missiles with fixed-step gravity and
velocity-facing rotation. Their non-damaging contacts activate one of 32 pooled
ten-frame ground hits and one of 40 pooled delayed five-frame smoke effects.
Each impact shares one seeded absolute `0.30x`–`0.52x` authored-size roll
between its hit and smoke animation. Consecutive rolls are kept visibly apart
when possible. Ground-hit frames also receive a large source-color outer glow
and tighter core glow during loading, with no runtime blur.
Both ground effects render above the tank and use the Continuous-mode ground
velocity while that mode is active.
Each trigger ejects one casing regardless of spread count. Casings inherit tank
velocity, leave from the cannon's local-right breech port, rotate under gravity,
touch the wheel-ground line using their rotated visible bounds, bounce twice,
skid briefly, and fade back into a 24-instance inactive pool.
Continuous casings visibly eject right before opposing map wind fades in near
the ground and strengthens across both rebounds toward full skid speed, without
changing bounce count, fade timing, or cleanup.
The Android native splash remains a solid dark screen so startup blends into
the Flutter loading sequence.

Reserved asset categories are:

```text
assets/
|-- backgrounds/
|-- branding/
|-- characters/
|-- credits/
|-- data/
|-- fonts/
|-- generated/
|-- misc/
|-- music/
|-- rewards/
|-- sounds/
`-- ui/
```

Empty categories contain `.gitkeep` files so the intended structure remains in
version control.

Run this after adding or removing assets:

```powershell
powershell -ExecutionPolicy Bypass -File tool\sync_asset_folders.ps1
```

The script updates only the generated asset block in `pubspec.yaml`. It ignores
`.gitkeep` and declares each directory containing supported runtime assets,
including nested skin directories.

To verify the manifest without modifying it:

```powershell
powershell -ExecutionPolicy Bypass -File tool\sync_asset_folders.ps1 -Check
```

## Platform Structure

### Android

The Android application uses:

- Application ID `com.orangehatboy.cannonmile`.
- Sensor landscape orientation.
- Hardware acceleration.
- Immersive fullscreen restoration on launch and resume.
- A guarded high-refresh-rate request from Dart.
- A dark native splash with no gameplay artwork.

The main manifest does not request network access. Flutter's debug and profile
manifests retain the permissions needed by development tooling.

Release signing is still a publishing concern. Configure a production keystore
before distributing an Android release.

The `display_mode` dependency currently requires the Android project to retain
its compatible Kotlin plugin setup. Recheck this configuration when upgrading
Flutter, Gradle, or the plugin.

### Windows

The Windows runner:

- Builds `cannon_mile.exe`.
- Uses Cannon Mile and Orange Hat Boy executable metadata.
- Opens a centered 16:9 window on the primary display.
- Uses a maximum target size of `1920 x 1080`.
- Uses a minimum size of `640 x 360`.
- Leaves 80 pixels of work-area padding where required.
- Preserves the 16:9 aspect ratio during native resize.

Platform-owned source changes belong in `windows/runner/`. Files below
`windows/flutter/` are generated by Flutter and should not be edited manually.

The project intentionally has no iOS or web platform folders.

## Development Commands

Run a Windows debug session:

```text
run_cannon_mile_dev.bat
```

The debug launcher owns one interactive Flutter session per workspace. Keep the
console titled `ACTIVE` focused and press `r` once for hot reload or `Shift+R`
for hot restart; Enter is not required. A second launcher is blocked so its
console cannot steal commands or collide with the active asset/build process.
Use hot restart after asset, constructor, or component-tree changes because hot
reload intentionally preserves the current game objects and state.

On Windows, the app uses the engine asset channel first and falls back to the
packaged `data/flutter_assets` directory if that channel is temporarily lost
during a hot restart. This keeps already-built branding and game sprites
available to both Flutter and Flame after the Dart isolate restarts. Newly added
or replaced asset files still require a full development-session restart so
Flutter can rebuild the asset bundle.

Build and launch the Windows release application:

```text
run_cannon_mile_windows.bat
```

Both launchers:

1. Find Flutter.
2. Remove stale CMake state when the project path has changed.
3. Synchronize asset folders.
4. Run `flutter pub get`.
5. Run or build the Windows application.

Run Android directly:

```powershell
flutter run -d android
```

Useful validation commands:

```powershell
flutter analyze
flutter test
flutter build windows --release
flutter build apk --debug
```

## Window Preview Tools

`tools/window_sizes/` contains common desktop viewport launchers:

- 1280 x 720
- 1366 x 768
- 1920 x 1080
- 2560 x 1440
- 3840 x 2160
- Ultrawide 2560 x 1080
- Ultrawide 3440 x 1440

The shared PowerShell launcher builds the Windows debug executable when needed
and passes the selected preview dimensions to the Flutter application.

## Test Coverage

The test suite mirrors the architecture:

| Test file | Coverage |
| --- | --- |
| `test/asset_manifest_test.dart` | Prevents unapproved assets from entering the Flutter bundle |
| `test/boot_controller_test.dart` | Progress, ordering, deduplication, timeouts, failures, and completion |
| `test/game_shell_test.dart` | Loading transition, lifecycle-safe held input, all six testing overlays, click isolation, and authoritative settings |
| `test/enemy_plane_spawn_test.dart` | Seeded two-to-four continuous plane waves, fast gaps, burst timing, direction, speed, and altitude-lane variety |
| `test/plane_combat_test.dart` | Level damage, swept moving-plane collision, replacement traffic, non-damaging missile physics, ground effects, hit flashes, pooled explosions, particles, and frame-rate coverage |
| `test/tank_pointer_swipe_tracker_test.dart` | Timestamp validation, signed swipe strength, direction changes, cap, reset, and frame-rate-independent decay |
| `test/raised_pressable_test.dart` | Press movement, callback delay, disable, cancellation, and disposal |
| `test/tank_bullet_level_test.dart` | Six-level bullet progression and the temporary five-sprite mapping |
| `test/tank_bullet_spread_level_test.dart` | Symmetric one-to-five projectile patterns and level wraparound |
| `test/tank_component_test.dart` | Movement, swipe dodge, pooled planes/projectiles/shells, shell physics and cleanup, real preload completion, Continuous track behavior, muzzle trails, firing, aiming, safe edges, and frame-rate stability |
| `test/tank_fire_rate_level_test.dart` | Evenly spaced six-level fire-rate values, progression, and wraparound |
| `test/tank_fire_sound_player_test.dart` | Native Windows audio routing, level-to-sound mapping, playback-rate variation, and pooled fallback selection |
| `test/tank_motion_test.dart` | Distance velocity, finite arrival, acceleration, braking, reversal thresholds/cadence, idle tuning, round-wheel response, and cannon aiming |
| `test/tank_speed_level_test.dart` | Six evenly spaced tank-speed caps from 600 to 720 and level wraparound |
| `test/virtual_stage_test.dart` | 16:9, common landscape, ultrawide, taller, and safe-area layouts |

When a new subsystem is introduced, its tests should be added beside the layer
that owns it. Gameplay rules should be testable without depending on visual
Flutter widgets.

## Adding the Next Gameplay Feature

A clean combat slice should follow this order:

1. Keep the existing tank movement and aiming behavior as the player base.
2. Build enemy attacks, player health, failure, and encounter rules on the
   current projectile-to-plane damage prototype.
3. Add scoring and rewards around plane destruction.
4. Expand scout planes with combat behavior.
5. Add a Flutter HUD under `lib/ui/overlays/`.
6. Expose only the minimum game state needed by the HUD.
7. Add assets to the matching asset category and synchronize the manifest.
8. Add focused tests before expanding the feature.

This keeps the world authoritative, the user interface replaceable, and the
startup path independent from gameplay content.

## Current Non-Goals

The repository does not currently contain:

- Enemy attacks, player health, terrain, recoil, ammunition, scoring, or
  authoritative encounter resolution. Current collision only covers player
  bullets damaging scout planes; casings remain visual only.
- Menus, settings, credits, privacy, shops, or game-over screens.
- Music, sound settings/mixing, fonts, or gameplay backgrounds beyond the six
  current level-matched gunfire effects.
- Saves, economy, progression, notifications, or online services.

Those systems should be introduced as Cannon Mile's design becomes concrete,
without importing legacy template-specific managers, pages, content, or
identifiers.
