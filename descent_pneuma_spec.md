# Descent — Pneuma System Integration Spec

**Purpose:** Add the Pneuma resource system and supporting HUD/audio feedback to the existing prototype. Do NOT remove or replace existing systems — layer on top of what's already working.

---

## Pneuma Resource System

### Overview

Pneuma is the core movement resource. Players spend Pneuma to perform advanced movement actions and earn it back by killing ground-based enemies. This creates a gameplay loop where players must engage enemies to fuel their mobility.

### Resource Pool

- `@export var max_pneuma: float = 100.0`
- `@export var current_pneuma: float = 100.0` (start full each level)
- `@export var pneuma_regen_rate: float = 0.0` (no passive regen — must be earned)

### Pneuma Costs (all values `@export` for tuning)

| Action | Cost | Notes |
|--------|------|-------|
| Dash | 20 | Quick burst of speed in movement direction |
| Double Jump | 15 | Second jump while airborne |
| Wall Jump | 10 | Jump off wall surface |

- If the player lacks enough Pneuma for an action, the action fails
- Play a "denied" audio cue and briefly flash the Pneuma HUD element red when an action is attempted without enough resource
- Base movement (sprint, single jump, bunny hop, air strafe) costs NO Pneuma — these are always available

### Pneuma Pickups

- Ground enemies drop Pneuma orbs on death
- `@export var pneuma_per_kill: float = 15.0`
- Orbs are physical objects that persist on the ground until collected
- Orbs have a magnetism/vacuum radius that pulls them toward the player
- `@export var pickup_base_radius: float = 2.0` (units — player must be relatively close)
- `@export var pickup_speed_bonus_radius: float = 3.0` (additional radius at max movement speed)
- Magnetism radius scales linearly with player speed: `effective_radius = pickup_base_radius + (current_speed / max_speed) * pickup_speed_bonus_radius`
- At walking speed: ~2 unit radius (basically walk over it)
- At full sprint/movement: ~5 unit radius (grab it from a nearby pass)
- Orbs should NOT be grabbable from wall-surf height in arenas without a dash/swoop. The radius rewards fast ground-level passes, not lazy wall camping
- Orbs fly toward the player once within magnetism radius (lerp quickly, ~0.3 sec travel time)
- Collecting a Pneuma orb should feel snappy — brief audio cue, small particle effect

### Enemy Integration

- Only ground-based enemies drop Pneuma orbs
- Flying enemies do NOT drop Pneuma (they are threats, not resources)
- For now, use existing enemy types. Tag them with a `drops_pneuma: bool` flag
- Ground enemies: `drops_pneuma = true`
- Flying enemies (when added): `drops_pneuma = false`

---

## HUD Elements

### Pneuma Meter

- Display as a horizontal bar, screen bottom-center or bottom-left (near health if it exists)
- Color: Light blue/white when healthy, transitions to orange below 30%, red below 15%
- Show numeric value next to the bar (e.g., "73/100")
- When Pneuma is spent, the bar should deplete with a smooth lerp (not instant)
- When Pneuma is gained from pickups, bar fills with a brief bright flash on the gained segment
- When an action is denied due to insufficient Pneuma, flash the entire bar red briefly (~0.2 sec)

### Feedback Indicators

- **Pickup collected:** Small "+15" floating text near the Pneuma bar, fades quickly
- **Low Pneuma warning:** When below 20%, pulse the bar gently to draw attention
- **Pneuma empty:** Bar should look visually "dead" — desaturated, no glow

---

## Audio Feedback

All audio is placeholder for now — use simple synth/UI sounds. The important thing is that every Pneuma interaction has SOME audio so we can feel the system working.

| Event | Sound Character |
|-------|----------------|
| Dash used | Whoosh + subtle resource spend sound |
| Double jump used | Air burst + subtle spend sound |
| Wall jump used | Light impact + subtle spend sound |
| Pneuma orb collected | Bright chime, satisfying ping |
| Action denied (no Pneuma) | Dull buzz/error tone |
| Low Pneuma (below 20%) | Subtle breathing/heartbeat loop |
| Pneuma empty | Distinct empty/hollow sound on attempted action |

---

## Movement Actions to Implement

If these don't already exist in the prototype, add them:

### Dash
- Quick burst in current movement direction
- `@export var dash_speed: float = 20.0`
- `@export var dash_duration: float = 0.15` (seconds)
- `@export var dash_cooldown: float = 0.5` (seconds — separate from Pneuma cost, prevents spam even with full meter)
- Can be used on ground or in air
- Brief camera FOV increase during dash for speed feel

### Double Jump
- Standard second jump while airborne
- `@export var double_jump_force: float = 8.0`
- Only available once per airborne period (reset on ground touch or wall jump)

### Wall Jump
- Jump off wall surfaces when player is adjacent and airborne
- `@export var wall_jump_force: float = 10.0`
- Pushes player away from wall + upward
- Should allow chaining wall jumps in corridors (left wall → right wall → left wall)
- Brief wall-slide state before jump (player sticks to wall for ~0.1-0.2 sec) to make timing forgiving

---

## Testing Checklist

After implementation, verify:

- [ ] Pneuma bar displays and updates in real-time
- [ ] Dash/double jump/wall jump consume correct Pneuma amounts
- [ ] Actions fail gracefully when Pneuma is insufficient (audio + visual feedback)
- [ ] Killing a ground enemy spawns a Pneuma orb
- [ ] Pneuma orbs magnetize toward player based on speed
- [ ] Pickup radius feels right — close passes grab, distant passes don't
- [ ] All audio cues play for each Pneuma event
- [ ] Pneuma meter color transitions work at thresholds
- [ ] System values are all @export and tuneable from the inspector
- [ ] Base movement (sprint, jump, air strafe, bhop) works without any Pneuma
