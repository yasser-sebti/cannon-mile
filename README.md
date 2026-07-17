# Cannon Mile

Cannon Mile is a landscape Flutter and Flame game prototype. It currently
launches through the complete production-style startup path and then displays
a layered player tank that follows the Windows mouse horizontally and aims its
cannon at the pointer. Cursor distance controls a heavy but responsive movement
speed, while high-quality filtered sprites keep the layered artwork smooth.

The repository contains the runtime architecture, loading system, responsive
stage, platform setup, lifecycle handling, reusable button behavior, tests,
development tools, and the first movement and animation prototype. Combat and
the complete game loop are not implemented yet.

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

`GameShell` mounts the Flame game immediately. The animated loading overlay is
drawn above it while the required boot tasks complete. Game initialization now
includes the tank skin and layered components. After the loading overlay fades
away, the mouse-controlled Flame prototype is revealed.

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
the current pointer target, and keeps the tank inside the visible width.

Current and future world objects belong below this world:

```text
CannonMileWorld
    + TankComponent
        + eased wheel1-to-wheel2 track morph
        + three speed-responsive bouncing round wheels
        + independently aimed cannon
        + anchored shaking base
    + enemies
    + projectiles
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

No Flutter overlay is currently displayed after loading. The visible prototype
is rendered entirely by Flame so mouse coordinates and tank movement share the
same virtual-stage coordinate system.

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

No button is currently displayed. Future buttons should compose their visual
style around this behavior rather than duplicating press animation logic.

## Loading Architecture

`BootOverlay` owns the launch presentation, while `BootController` owns task
execution.

The production visual sequence is:

1. Pop the logo from 78% to 100% over 420 ms with `easeOutBack`.
2. Wait 500 ms before showing loading details.
3. Display the orange progress bar, percentage, and current task.
4. Hold the completed state for 300 ms.
5. Fade the loading overlay out over 800 ms.

The default boot tasks run in order:

1. Resolve the Orange Hat Boy logo.
2. Await `CannonMileGame.initialized`.
3. Prime the first rendered Flutter interface frame.

Each task has a 10-second timeout. Task failures and timeouts are logged and
then treated as complete so a recoverable startup problem cannot trap the
player permanently on the loading screen.

`BootController.run()` is deduplicated. Multiple calls during startup share the
same future and do not execute the task list more than once.

Add a new boot task only when something must be ready before the first usable
screen. Optional content and gameplay assets should be loaded later by the
feature that owns them.

## Assets

The active assets are:

```text
assets/branding/orange_hat_boy_logo.webp
assets/tank skins/default-skin/
|-- base-tank.webp
|-- tank-canon.webp
|-- wheel-rounded.webp
|-- wheel1.webp
`-- wheel2.webp
```

The branding image is used by the Flutter loading overlay and as the source for
native launcher icons. The tank files form the first game-specific skin. The
Android native splash remains a solid dark screen so startup blends into the
Flutter loading sequence.

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
| `test/game_shell_test.dart` | Loading transition, lifecycle handling, and the typed world/tank relationship |
| `test/raised_pressable_test.dart` | Press movement, callback delay, disable, cancellation, and disposal |
| `test/tank_component_test.dart` | Filtered layer composition, eased track morphing, speed-responsive wheel motion, frame-rate stability, bounds, and overshoot |
| `test/tank_motion_test.dart` | Distance-based velocity, acceleration, braking, reversal, wheel response, and 180-degree cannon aiming |
| `test/virtual_stage_test.dart` | 16:9, common landscape, ultrawide, taller, and safe-area layouts |

When a new subsystem is introduced, its tests should be added beside the layer
that owns it. Gameplay rules should be testable without depending on visual
Flutter widgets.

## Adding the Next Gameplay Feature

A clean combat slice should follow this order:

1. Keep the existing tank movement and aiming behavior as the player base.
2. Define firing, health, failure, and encounter rules.
3. Add projectiles and combat logic under `lib/game/systems/`.
4. Add the first enemy component and spawning behavior.
5. Add a Flutter HUD under `lib/ui/overlays/`.
6. Expose only the minimum game state needed by the HUD.
7. Add assets to the matching asset category and synchronize the manifest.
8. Add focused tests before expanding the feature.

This keeps the world authoritative, the user interface replaceable, and the
startup path independent from gameplay content.

## Current Non-Goals

The repository does not currently contain:

- Firing, enemies, projectiles, terrain, damage, or collision.
- Menus, settings, credits, privacy, shops, or game-over screens.
- Audio, music, fonts, or backgrounds beyond the tank skin.
- Saves, economy, progression, notifications, or online services.

Those systems should be introduced as Cannon Mile's design becomes concrete,
without importing legacy template-specific managers, pages, content, or
identifiers.
