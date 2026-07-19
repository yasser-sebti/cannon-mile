# About Cannon Mile

Cannon Mile is a fast-paced, side-scrolling arcade action game in which the
player commands a mobile cannon fighting its way through a long and dangerous
route.

The cannon moves continuously through hostile territory while enemies attack
from the ground and the air. The player must aim, fire, avoid incoming attacks,
destroy enemy forces, and survive increasingly difficult encounters while
trying to travel farther along the route.

The game is based on the broad arcade concept popularized by **Heavy Weapon**:
controlling an armed ground vehicle, moving across a scrolling battlefield,
and fighting large waves of enemies with simple, immediate controls. Cannon
Mile will use that general idea as inspiration while developing its own
gameplay systems, world, vehicles, enemies, weapons, progression, visual style,
audio, story, and identity.

The intended experience is easy to understand but difficult to master. Short,
responsive combat encounters will build into longer runs featuring stronger
enemy combinations, temporary upgrades, weapon choices, major threats, and
increasing pressure.

Cannon Mile is currently in its first movement, animation, and visual-fire
prototype stage.
The Windows build contains a layered tank with two testing modes. Both follow
the mouse horizontally, slow with a finite heavy arrival, and respect safe
screen margins. Maximum edge boost eases continuously through the outer side
band instead of switching on when the pointer crosses the tank boundary. A
timestamped fast swipe inside that band can request a temporary moderate dodge
boost without turning ordinary slow edge aiming into turbo movement.
Continuous keeps restrained persistent track, wheel, and
chassis motion active to simulate forward travel, while Boss Fight can settle
completely still. Both modes aim through the upper 180-degree arc while the
cannon mount travels along a shallow upside-down U. A seventh test control now
switches between the normal projectile weapon and an unlimited ultimate laser.
Holding fire in Laser mode instantly snaps a white/yellow/orange beam outward
from the exact muzzle with no fade-in and overdraws it beyond the viewport
without an endpoint flare. A flattened, layered half-ellipse rounds the beam at
the cannon instead of leaving a flat clipped edge. The cannon follows through a
slightly faster but deliberately heavy angular spring while tank movement
remains unchanged. Sixteen beam states are baked with Gaussian glow
during loading; rapid cached shake, shine, and beam-anchored side particles add
energy without runtime blur or independent particle physics. After reaching
35% power, the
bright core pierces and instantly destroys every intersected plane and missile
through the existing pooled destruction effects. A start cue and sustained
loop are preloaded. The laser has no muzzle flash, muzzle-particle burst,
bullets, casings, ammunition, or cooldown.
Holding the primary mouse
button now previews a fast four-pose muzzle flash with six rapid-fire settings.
The flash uses 16 pre-baked animation composites with a lighter Gaussian halo
and three tapered additive speed-lens streaks. Runtime firing draws one cached
image without a blur filter, blend layer, or per-shot effect allocation.
The complete tank hierarchy renders at 70% authored size, with its muzzle flash
inheriting the same transform and detached bullets explicitly matching it.
Continuous track animation uses a stronger forward idle cadence and continues
during slow backing,
then reverses at a faster cadence during fast backing without changing the
round-wheel tuning. Its maximum-speed cadence is strongly capped independently
of the round wheels. Each shot randomly mirrors its muzzle flash and plays the
gunfire sound matching its bullet level at individually balanced volume, with a
subtle randomized `0.95x` to `1.05x` playback speed. Each shot emits four small
pooled muzzle sparks. Their colors and alpha-visible bounds are sampled from the
supplied muzzle artwork during loading. The bottom pair begins near the inner
muzzle corners with a wide outward angle, while the upper pair begins beyond
the visible left and right edges and angles slightly outward, then all use a brief
cannon-relative blast with spread, drag, gravity, shrinking, and fade-out.
Firing for at least 0.5 seconds arms a procedural heat plume but never displays
it while the trigger remains held. Once firing ends and the final muzzle flash
completes, the wavy gray-gradient strip grows behind the cannon tip for 2.4
seconds. Muzzle heat persists for five seconds and lets even one subsequent
shot refresh the post-flash smoke, while cold single shots remain smoke-free.
Persistent plume segments lag behind tank and aiming motion like a
narrow flag in the wind. A heavy fixed base and progressively lighter upper
segments preserve the free tip's position while the cannon pulls its anchor.
Continuous travel adds constant right-to-left apparent wind. The plume remains
slightly inside and behind the cannon tip, world-up, while it bends and fades.
Gunfire samples and a bounded voice pool are prepared during loading, while
Windows queues playback on a dedicated worker so audio recycling cannot stall
gameplay animation. Plane missiles have one health and can be intercepted by a
single bullet using swept rotated-triangle collision. Destruction immediately
returns the missile to its pool and plays a smaller version of the cached plane
explosion, animated smoke, and both pooled smoke-particle profiles. Missile
gravity and initial descent are slightly reduced. Lingering secondary smoke
from every air explosion inherits the exact Continuous-mode ground-scroll
velocity, while immediate smoke bursts remain physically independent.
Aircraft render an enlarged ten-frame fan behind and slightly below the nose
using fractional crops from one optimized sprite sheet. It runs at 90 frame
transitions per second, and the entire composition mirrors with direction. One
shared immutable visual template groups the body, fan, authored mount, bounds,
and spawn footprint behind a single whole-aircraft scale.
Bullet artwork has six placeholder levels,
while a separate five-level
spread upgrade fires substantially wider symmetric patterns from level two
onward at one fixed projectile speed. A six-level tank-speed test control ranges
from 600 to the reduced 720-pixel-per-second maximum. Edge turbo remains locked
until the tank is already moving at a safe fraction of its selected cap.
Five supplied bullet sprites retain their source canvases and glow padding, but
higher levels render at restrained scales, including small reductions for
levels two through four; the sixth artwork level temporarily
reuses the strongest sprite, and the first four receive progressively lighter
RGB-only brightness reduction baked during loading. Every shot ejects one tiny
level-matched casing from the cannon's local-right side. The casing inherits
tank motion, rotates under gravity, makes two restrained bounces against the
exact wheel-ground edge, skids, and fades into a 24-object inactive pool. While
Continuous travel is active, casings visibly eject to the right first. The
opposing map wind fades in near the ground, then strengthens smoothly across
the two bounces toward full ground drift while retaining normal fade timing.
Bullets now use alpha-aware swept collision against scout planes, resolving the
first visible projectile-core pixel against the mirrored aircraft silhouette.
Every plane has six health, bullet levels deal one through six damage, and
nonlethal hits receive a visible damage-scaled red overlay that fades over
100 ms. Each hit plays a tiny pre-glowed ten-frame downward impact over 70 ms
and emits 12–16 orange physics particles. One of three non-repeating metal-hit
sounds plays at 5.46% volume with randomized `0.90x`–`1.10x` speed. Twenty-four
pre-created non-interrupting voices spill saturated variations into another
available clip, preserving rapid hits without replay cutoffs, delay, or mute.
Ground explosions use the same overlap strategy. Lethal hits replace the plane with a
pooled six-frame explosion with pre-baked source-color glow. The burst
smoothly changes size and fades over 228 ms; immediate six-frame smoke animates
behind it while 14–18 smoke chunks split into an immediate burst and a delayed,
slow-rising inverted-triangle plume that lingers before smoothly shrinking away.
The first ground contact of each casing requests one of four randomized impact
sounds without immediate repetition. A shared cooldown suppresses dense sound
buildup. A toggleable scout-plane spawner now produces continuous randomized
two-to-four-plane bursts from either side, using safe upper-screen
altitude lanes and uniformly randomized `280–700` speed. Predictive lane
reservations keep same-direction planes at least 1.5 plane widths apart, while
opposite directions receive small vertical offsets. Destroyed planes request a
replacement after 60 ms. Active aircraft periodically release pooled triangle
missiles that curve downward under gravity but deal no damage. Ground contact
renders a ten-frame hit and delayed
five-frame smoke above the tank;
both share a randomized `0.30x`–`0.52x` authored-size scale with visibly
separated consecutive rolls and drift with the
simulated ground in Continuous mode. One of three non-repeating impact sounds
plays at 2.2295% volume on contact through non-interrupting pooled voices. Twenty pooled planes, 96
pooled bullets, 64 plane missiles, 32 ground hits, 40 ground-smoke animations,
24 pooled casings, 12 impact effects, 12 explosions, 12 smoke animations, 256
smoke chunks, and 256 hit particles avoid
recurring gameplay allocation.

The branded loading sequence reports real image, audio, visual-cache, pool, and
renderer warm-up progress. Track morphs, projectile brightness, muzzle
composites, ultimate-laser glow states, collision masks, glowing hit frames,
large dual-radius plane and
ground-hit explosion glows, smoke,
red overlays, and particles are prepared before two
covered render frames exercise the resulting runtime paths. Missile damage,
full enemy attacks, encounters, player health, scoring, progression, a complete
audio system, and the full game loop remain future milestones.
