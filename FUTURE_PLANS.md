# Cannon Mile Future Plans

This document is the working development roadmap for Cannon Mile. It describes
what should be built next, the intended order of work, and the conditions that
must be met before moving to the next milestone.

The roadmap begins from the current repository state: a tested Flutter and
Flame foundation with a Windows mouse-controlled tank movement, animation,
visual muzzle-fire, and directional projectile prototype inside
`CannonMileWorld`.

For the current code structure, see [README.md](README.md).

## Working Game Direction

Cannon Mile is planned as an original landscape arcade action game about
guiding a mobile cannon through a dangerous route. The player survives enemy
waves, controls movement and aim, destroys threats, collects temporary
advantages, and tries to push farther along the route.

The working design pillars are:

- **Immediate:** movement, aiming, and firing should feel understandable within
  the first few seconds.
- **Readable:** threats, projectiles, damage, and safe movement space must remain
  clear on a phone-sized landscape display.
- **Mobile:** the cannon and the route should create continuous forward
  momentum rather than a stationary shooting gallery.
- **Replayable:** changing enemy combinations and upgrade choices should make
  repeated runs meaningfully different.
- **Original:** game identity, rules, content, visuals, audio, writing, and
  progression must be created specifically for Cannon Mile.

This direction is a starting point, not a locked game design document. Exact
controls, camera behavior, run length, progression, and monetization remain
open decisions until the greybox prototype proves what is enjoyable.

## Status Legend

| Status | Meaning |
| --- | --- |
| Complete | Implemented and verified in the repository |
| Next | The current milestone to design and implement |
| Planned | Expected after earlier dependencies are stable |
| Optional | Valuable, but not required for the first release |
| Undecided | Requires a deliberate product or design decision |

## Roadmap Summary

| Milestone | Status | Outcome |
| --- | --- | --- |
| 0. Runtime foundation | Complete | Reliable branded launch into a responsive Flame world |
| 1. Design lock and technical contracts | Next | A small, testable definition of the first playable game loop |
| 2. Greybox vertical slice | Planned | One complete playable encounter using temporary shapes |
| 3. Core combat systems | Planned | Reusable player, weapon, enemy, collision, spawning, and scoring systems |
| 4. Run structure and progression | Planned | A complete start-to-result gameplay loop with saved progress |
| 5. Original content and interface | Planned | Production assets, sound, menus, HUD, information, and legal pages |
| 6. Optimization and accessibility | Planned | Stable performance and usable controls across supported devices |
| 7. Release preparation | Planned | Signed, tested, store-ready Android and Windows builds |
| 8. Post-launch expansion | Optional | Additional modes, routes, enemies, weapons, and platform support |

## Milestone 0: Runtime Foundation

**Status: Complete**

The current project provides:

- Flutter and Flame application scaffolding.
- Typed `FlameGame<CannonMileWorld>` ownership.
- Android and Windows platform runners.
- Landscape and immersive Android behavior.
- Guarded high-refresh-rate activation.
- Responsive `1920 x 1080` virtual-stage calculations.
- Ultrawide, taller-display, and safe-area support.
- Animated Orange Hat Boy loading presentation.
- Real image, audio, component-pool, and two-frame renderer warm-up progress.
- Ordered, timed, fail-soft boot tasks.
- Application lifecycle pause and resume.
- A reusable raised-button interaction foundation.
- Asset-folder synchronization tooling.
- Desktop resolution preview launchers.
- Unit and widget tests for the foundation.
- A first layered tank skin, horizontal mouse following, upper-arc cannon aim,
  an arched cannon mount, safe viewport-edge travel with a continuously eased
  outer-band boost plus a timestamped moderate swipe-dodge override,
  high-quality filtered
  rendering, switchable Continuous/Boss testing modes, finite heavy arrival,
  persistent directional track-frame interpolation across four supplied poses,
  a uniformly scaled 70% tank/effect/projectile presentation, speed-responsive
  wheel and chassis animation, stronger Continuous track-idle cadence, a
  forward Continuous-idle/slow-reverse track cadence with a fast-reverse
  threshold and boost plus a stronger maximum-speed track cap, a
  held-primary-mouse four-pose muzzle flash with randomized horizontal mirroring
  plus 16 pre-baked light-Gaussian composites, three tapered speed-lens streaks,
  and six deterministic
  test rates, and six placeholder
  bullet-artwork levels using five supplied sprites. Six tank-speed caps span
  600 through the reduced 720 maximum, with velocity-gated edge turbo.
  Projectile speed is fixed, spread
  has five widened symmetric one-to-five shot levels, and each shot uses the
  gunfire sound matching its bullet level at balanced 10.35125%–20.7025% volume with randomized
  `0.95x` to `1.05x` playback speed. Windows routes these sounds through a
  pre-attenuated, fixed runner-native voice pool driven by a non-blocking audio
  worker, while other targets retain a bounded preloaded pool. Higher artwork levels use restrained render scales
  and the first four levels receive progressively lighter RGB-only brightness
  reduction. A seeded-testable scout-plane spawner creates continuous randomized
  two-to-four plane waves, directions, `280–700` speeds, fast gaps, and safe altitude lanes.
  Predictive 1.5-width spacing prevents same-direction overlap. Twenty pooled
  planes, 96 pooled bullets, and 24 level-matched casings remove recurring spawn
  allocation. Each shot ejects one casing with cannon-relative motion, gravity,
  rotation, two exact ground-edge bounces, skid, and fade-out reuse. Casings
  eject right before the opposing Continuous-travel wind fades in near the
  ground and strengthens smoothly across each bounce. Player bullets now use
  alpha-aware swept core collision against six-health planes, with
  level-one-through-six damage, a cached 48–65% pure-red 100 ms overlay fade,
  a tiny pre-glowed 70 ms downward impact animation, and 12–16 pooled orange
  physics particles per contact. Three non-repeating metal-hit clips play at
  4.2% volume with randomized `0.90x`–`1.10x` speed through 24 pre-created,
  non-interrupting voices. Saturated metal-hit and ground-explosion variations
  spill into another available clip instead of restarting, delaying, or muting.
  Transparent aircraft corners do not register
  hits, and mirrored sprites resolve contact against the same source mask.
  Destroyed planes transition into pooled six-frame size-eased explosions with
  pre-baked color glow, accompanied immediately by animated smoke and two
  pooled physics-smoke profiles: fast burst chunks plus delayed, slow-rising
  lingering chunks arranged as an inverted-triangle upward plume. Destroyed
  aircraft request a 60 ms replacement. Active aircraft drop pooled visual-only
  triangle missiles with curved gravity physics. Ground contact uses ten hit
  frames and five
  delayed smoke frames above the tank, with a shared randomized
  `0.30x`–`0.52x` scale with visibly separated consecutive rolls,
  Continuous-mode ground drift, pre-baked dual-radius outer glow, and randomized
  non-repeating 1.715%-volume bomb impact audio. Eight voices per clip preserve
  up to 24 overlapping tails and spill across available variations instead of
  resetting an active sound. First casing-ground contacts use four randomized non-repeating
  sounds behind a shared cooldown and bounded voice pool.

This milestone should remain stable while gameplay is developed. New features
must not make optional gameplay content a requirement for reaching the first
usable screen.

## Milestone 1: Design Lock and Technical Contracts

**Status: Next**

Before implementing final assets, write a small game design specification that
answers only the questions needed for the first playable slice.

### Design Decisions

- Define the player's primary objective.
- Decide whether the route scrolls automatically or responds to player speed.
- The current prototype compares persistent continuous-travel animation with a
  fully stopping boss mode; both use horizontal mouse-following movement.
- Select the first input model:
  - twin-stick touch controls;
  - drag-to-move and drag-to-aim;
  - movement control with automatic targeting;
  - Windows currently uses direct mouse hover for movement and aiming.
- Define authoritative firing and reload behavior beyond the current basic
  projectile-to-plane damage prototype.
- Define player health, failure, and restart rules.
- Define the first enemy's movement and attack behavior.
- Define a short encounter with a measurable win condition.
- Set the desired session length for the prototype.

### Technical Contracts

- Define a game-state enum such as loading, ready, playing, paused, won, and
  defeated.
- Decide how Flutter overlays observe selected game state without owning it.
- Define input commands independently from physical touch, mouse, or keyboard
  events.
- Define collision categories before adding multiple component types.
- Define data objects for weapon and enemy tuning values.
- Define which values must be deterministic for tests.
- Set initial component-count and frame-time budgets.

### Exit Criteria

Milestone 1 is complete when:

- A one-page gameplay specification exists.
- The first control model and Windows equivalent are documented.
- The first encounter has a clear start, success, and failure condition.
- State ownership between Flame and Flutter is documented.
- No final artwork is required to implement the specification.

## Milestone 2: Greybox Vertical Slice

**Status: Planned**

Build one complete playable encounter using primitive shapes and temporary
effects. This milestone exists to test whether the core interaction is fun
before spending time on production assets.

### Game Components

Suggested initial files:

```text
lib/game/
|-- components/
|   |-- player_cannon.dart
|   |-- enemy.dart
|   `-- projectile.dart
|-- systems/
|   |-- input_system.dart
|   |-- combat_system.dart
|   `-- spawn_system.dart
|-- modes/
|   `-- prototype_mode.dart
|-- cannon_mile_game.dart
`-- cannon_mile_world.dart
```

Names may change once the design specification is complete. Responsibilities
should remain separated even if the first implementation is small.

### Required Slice

- Retain the existing controllable, animated player tank.
- Support touch input and a Windows development input.
- Aim and fire one weapon.
- Spawn one original enemy behavior.
- Resolve projectile hits and damage.
- Show player damage and enemy destruction clearly.
- Track either distance, score, or encounter progress.
- Provide pause, defeat, victory, and restart behavior.
- Display a minimal Flutter HUD using temporary styling.
- Keep the Orange Hat Boy startup flow unchanged.

### Technical Requirements

- Gameplay state remains in Flame.
- Flutter presents HUD and menu state through a narrow interface.
- Collision logic is testable without loading production images.
- Temporary rendering uses Flame shapes or clearly marked developer assets.
- Repeated projectiles and enemies do not create uncontrolled allocations.
- The game pauses correctly when the app loses focus.

### Exit Criteria

Milestone 2 is complete when:

- A new player can understand the controls without developer assistance.
- The complete encounter can be won, lost, and restarted.
- The interaction remains readable at 1280 x 720 and on ultrawide displays.
- Automated tests cover damage, defeat, victory, and restart.
- The debug and release builds remain free of uncaught launch errors.
- The team chooses to keep, revise, or reject the prototype based on playtesting.

## Milestone 3: Core Combat Systems

**Status: Planned**

After the vertical slice proves the core interaction, turn prototype behavior
into reusable systems.

### Player and Weapons

- Finalize movement acceleration, limits, and recovery.
- Add weapon fire rate, projectile speed, damage, spread, and reload data.
- Support more than one weapon without hard-coding behavior into the player.
- Add damage feedback, invulnerability timing, and defeat effects.
- Add controller-independent input commands.
- Decide whether assisted aim or automatic targeting is needed on mobile.

### Enemies

- Create at least three mechanically distinct, original enemy archetypes.
- Separate enemy tuning data from movement and attack code.
- Add spawn warnings where off-screen threats could feel unfair.
- Define consistent health, contact damage, projectile damage, and reward rules.
- Add object reuse or pooling once measurements show it is needed.

### Encounter Direction

- Introduce a spawn director that controls pacing and difficulty.
- Use authored encounter data or weighted rules instead of scattered timers.
- Prevent unavoidable combinations through spacing and threat-budget rules.
- Expose debug controls for spawning and difficulty testing.

### Feedback

- Add hit flashes, recoil, impact effects, camera response, and readable damage
  feedback.
- Keep effects independent from authoritative combat calculations.
- Add settings for reducing shake, flashes, and vibration.

### Exit Criteria

- Adding a weapon or enemy does not require editing unrelated systems.
- Combat values can be tuned without changing rendering code.
- Enemy combinations remain readable and avoid unavoidable damage.
- Combat rules have focused unit tests.
- Performance remains inside the agreed frame budget during a stress encounter.

## Milestone 4: Run Structure and Progression

**Status: Planned**

Turn individual encounters into the first complete game loop.

### Run Flow

```text
Title
    -> Start run
    -> Route encounters
    -> Upgrade or recovery choice
    -> Harder encounters
    -> Route completion or defeat
    -> Results
    -> Restart or return to title
```

### Planned Systems

- Route distance and encounter progression.
- Difficulty progression based on explicit rules.
- Temporary in-run upgrades.
- Score and result calculation.
- Pause and resume.
- A clean run reset that removes old components and transient state.
- Local settings and save data with schema versioning.
- Recovery from missing or invalid save data.

### Progression Guardrails

- The base game must be enjoyable without permanent upgrades.
- Permanent progression should unlock options rather than merely repair weak
  controls or unfair balance.
- Save data must contain game data, not references to live Flame components.
- Economy and reward systems should not be created until their purpose is
  documented.

### Exit Criteria

- A player can enter, complete or lose, review results, and start another run.
- Restarting does not leak components, timers, listeners, or overlays.
- Save migration and corrupted-save fallback are tested.
- The first run remains understandable without a tutorial page.

## Milestone 5: Original Content and Interface

**Status: Planned**

Production assets should begin only after the greybox loop and screen
composition are approved.

### Visual Identity

- Create an original Cannon Mile logo and title treatment.
- Establish a color palette, shape language, and readability rules.
- Design an original player cannon silhouette.
- Design original enemies with distinct threat silhouettes.
- Create modular route or terrain pieces suited to responsive landscape screens.
- Create original projectiles, impacts, explosions, pickups, and UI icons.
- Document asset dimensions, pivots, export formats, and naming conventions.

### Audio

- Expand the current native-Windows/pooled-other-platform gunfire playback into
  a complete audio manager only as more sound assets become ready.
- Separate music, interface sounds, weapons, impacts, and ambience.
- Provide independent music and sound-effect volume controls.
- Handle lifecycle pause, interruption, and resume.
- Verify the license and source of every audio file.

### Flutter Interface

- Title and play flow.
- Gameplay HUD.
- Pause and results overlays.
- Settings page.
- Controls and accessibility page.
- Credits page.
- Privacy page if data collection, analytics, advertising, or store requirements
  make it necessary.
- Version information and license acknowledgements.

All pages should be designed for the existing virtual-stage and safe-area
system. Buttons should reuse `RaisedPressable` where its behavior fits.

### Asset Acceptance Rules

Every production asset must be:

- Created specifically for Cannon Mile, properly commissioned, or covered by a
  license allowing the intended commercial use.
- Stored with source and license records outside or alongside the runtime bundle
  as appropriate.
- Named according to its Cannon Mile function rather than a reference game's
  terminology.
- Added to the appropriate asset category.
- Declared through `tool/sync_asset_folders.ps1`.
- Verified to be absent from the bundle when unused.

## Milestone 6: Optimization and Accessibility

**Status: Planned**

Optimization should be measurement-driven. Avoid adding complex pooling,
caching, or custom rendering before a profile identifies a real cost.

### Performance Targets

- Establish a supported-device baseline before final optimization.
- Maintain a stable 60 frames per second on the baseline Android device.
- Use higher refresh rates when supported without making gameplay speed depend
  on frame rate.
- Avoid frame-time spikes during spawning, destruction, and route transitions.
- Keep boot reliable when optional content is unavailable.
- Monitor memory across repeated runs and restarts.

### Profiling Work

- Record component counts during normal and stress encounters.
- Profile CPU and raster work in Flutter DevTools.
- Inspect texture memory and atlas usage after production art is integrated.
- Measure allocation pressure from projectiles, particles, and enemies.
- Test release builds because debug performance is not representative.

### Accessibility and Usability

- Remappable or selectable control layouts where practical.
- Left-handed touch layout support if the chosen controls require it.
- Adjustable screen shake, flashes, vibration, music, and sound effects.
- Color and shape cues that do not rely on color alone.
- Legible UI at all supported preview resolutions.
- Safe-area compliance on cutout and rounded-corner displays.
- Pause behavior that does not punish platform interruptions.

### Exit Criteria

- Baseline devices meet the selected frame-time target.
- Repeated runs do not show meaningful memory growth.
- Controls remain usable on small landscape screens.
- Accessibility settings persist correctly.
- All supported aspect ratios pass layout tests.

## Milestone 7: Release Preparation

**Status: Planned**

### Product and Legal

- Lock the final product name after a fresh trademark and storefront search.
- Register or document ownership of commissioned artwork, audio, and writing.
- Complete credits and third-party license notices.
- Publish a privacy policy matching the actual data behavior.
- Remove unused permissions, services, dependencies, and assets.
- Confirm age rating and content disclosures.

### Android

- Configure a production package identity if it changes before release.
- Create and securely store a release signing key.
- Configure release signing outside source control.
- Verify current target SDK and store requirements.
- Test install, update, pause, resume, audio interruption, and process recovery.
- Produce store icons, screenshots, feature graphics, and release notes.

### Windows

- Verify executable metadata and final icon.
- Test on clean supported Windows installations.
- Select an installer or distribution format.
- Decide whether code signing is required for the chosen distribution channel.
- Verify window behavior across common display scaling settings.

### Quality Gates

- `flutter analyze` returns no issues.
- `flutter test` passes.
- Android and Windows release builds succeed from a clean checkout.
- No developer-only assets, controls, logs, or preview behavior ship enabled.
- A cold launch reaches the title or playable state without network access.
- Save data survives upgrades or migrates safely.
- Crash and performance testing covers long sessions and repeated restarts.

## Milestone 8: Post-Launch Expansion

**Status: Optional**

Possible additions after a stable release:

- New route themes with new encounter rules.
- Additional weapon families.
- New enemy factions and boss-style encounters.
- Challenge, endless, or score-attack modes.
- Daily or seeded challenges without requiring always-online play.
- Achievements and platform integration.
- Additional controller support.
- Localization.
- iOS support.

Online accounts, competitive multiplayer, advertising, analytics, and
monetization are deliberately not assumed. Each would require a separate
design, privacy, operational, and maintenance decision.

## Originality and Copyright Guardrails

As a project policy, Cannon Mile may take inspiration only from broad genre
ideas such as an arcade vehicle, forward movement, aiming, firing, enemies,
upgrades, and boss encounters. Its specific expression must remain original.
These are practical development guardrails, not legal advice.

Development must not copy:

- Another game's title, logo, characters, story, dialogue, or fictional terms.
- Specific vehicle, enemy, weapon, level, map, or boss designs.
- Artwork, animation frames, sound effects, music, fonts, or source code.
- Distinctive menu composition, HUD art, screen transitions, or visual trade
  dress.
- Exact level sequences, enemy-wave scripts, upgrade trees, balance tables, or
  written descriptions.

Reference games can be used to discuss genre expectations and design problems.
Every Cannon Mile implementation should be independently designed, named,
coded, and documented. Final naming and publishing decisions should receive
professional trademark and legal review when commercial risk justifies it.

## Architecture Rules for Future Work

These rules preserve the current project boundaries:

1. `CannonMileWorld` owns gameplay components and authoritative simulation
   state.
2. Flame components do not directly build Flutter pages.
3. Flutter widgets do not become the authoritative owner of combat or run
   state.
4. Cross-component behavior belongs in a system, not duplicated across actors.
5. Long-lived managers are introduced only for a defined service boundary.
6. Boot tasks contain only work required before the first usable screen.
7. Optional content failures must not permanently block application launch.
8. Rendering effects do not decide damage, scoring, or progression.
9. Tuning data is separated from component rendering where practical.
10. Every persistent data format has a version and a safe fallback.
11. New assets enter the manifest only when they are used.
12. New dependencies require a specific need and platform compatibility check.

## Immediate Next Actions

The recommended next development session is Milestone 1:

1. Create a one-page gameplay specification.
2. Playtest and tune the implemented horizontal mouse-following movement.
3. Choose and document the first touch-control model.
4. Define the first 60-to-90-second encounter and firing behavior.
5. Define game state and Flutter-to-Flame state exposure.
6. Define projectile and first-enemy data, then implement them with shapes.

The first implementation goal is not a large content build. It is one short,
complete, readable encounter that proves Cannon Mile's controls and combat are
worth expanding.

## Updating This Roadmap

When work is completed:

- Change the relevant milestone status.
- Check the exit criteria against the actual build.
- Move rejected ideas out of the active milestone instead of leaving them
  ambiguous.
- Record significant product decisions in the milestone that depends on them.
- Keep future ideas below the stable core rather than interrupting the current
  playable goal.

This file describes intended work. The repository and automated tests remain
the source of truth for what is currently implemented.
