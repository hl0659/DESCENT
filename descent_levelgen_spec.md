# Descent — Level Generation Spec (Prototype)

**Purpose:** Get a basic procedural level generator running that produces playable, visually readable levels. Priority is testable spaces for tuning movement and Pneuma, not final art.

---

## Visual Style (Prototype)

Levels must be visually readable. No uniform colors or untextured white.

### Color Palette

| Surface | Color (Hex) | Notes |
|---------|-------------|-------|
| Floor | `#2A2A3A` | Dark slate blue-grey |
| Walls | `#3D3D50` | Slightly lighter than floor |
| Ceiling | `#1E1E2E` | Darkest surface |
| Wall trim/edges | `#6A5ACD` | Slate blue accent on wall borders — helps read geometry |
| Arena floor | `#332233` | Slightly warmer to signal "different zone" |
| Arena walls | `#443355` | Purple tint distinguishes arena from hallway |
| Platforms | `#4A4A5A` | Lighter than floor so they pop |
| Doors/transitions | `#8B7500` | Gold/amber — signals progression |
| Vault door | `#2E8B57` | Green — signals optional/reward |

### Textures

- Apply a simple grid/tile texture to floors (helps player read speed and distance)
- Walls get a subtle vertical line texture (helps read wall surfaces for wall jumps)
- Grid scale: ~2 meter squares on floors, ~1 meter vertical lines on walls
- Use Godot's built-in StandardMaterial3D with albedo color + a tiling noise or checker pattern
- Even a basic UV-mapped grid texture is fine — the goal is spatial readability, not beauty

### Lighting

- Each room/segment gets at least one OmniLight3D or SpotLight3D
- Hallways: dim, cool-toned lights spaced evenly (slight blue tint)
- Arenas: brighter, slightly warmer lighting (player should feel the space open up)
- Transitions: amber/gold light near doorways to guide the player forward
- `@export` light intensity and color on the generator so we can tune mood later

---

## Building Blocks

The generator assembles levels from prefab scene chunks. Each chunk is a standalone `.tscn` with standardized connection points.

### Connection Points

- Every chunk has one or more **doorways** at its edges
- Doorways are standard size: 3m wide × 4m tall
- Doorways are defined by Marker3D nodes named `entry` and `exit` (or `door_01`, `door_02` etc for multi-exit chunks)
- Generator connects chunks by aligning doorway markers

### Chunk Types

#### 1. Hallway Straight
- Dimensions: ~30m long × 6m wide × 6m tall
- One entry, one exit (opposite ends)
- Walls on both sides suitable for wall jumping (parallel, consistent height)
- Floor has minor elevation changes (small ramps, steps) for movement variety
- Spawn points: 2-4 ground enemy positions along the length
- Lighting: 2 dim overhead lights

#### 2. Hallway Curve
- Same cross-section as straight, but turns 45 or 90 degrees
- Outer wall is longer (good for extended wall runs)
- Spawn points: 1-3 ground enemies around the bend

#### 3. Hallway Vertical (Ramp Up / Ramp Down)
- Transitions the level up or down in elevation (~6-8m change)
- Can be a steep ramp, a series of platforms, or a drop with a slide-friendly slope
- Entry and exit at different heights
- Spawn points: 1-2 enemies on the slope or at top/bottom

#### 4. Small Arena
- Circular or octagonal, ~20m diameter, ~10m tall
- Entry and exit on opposite sides
- Concave/curved walls suitable for wall running along the perimeter
- One platform bridge across the center (3m wide, ~5m off the ground)
- Spawn points: 6-10 ground enemies, 2-3 flying enemy positions (elevated)
- Arena trigger zone: when player enters, doors lock, enemies spawn in 1-2 waves
- Doors unlock when all enemies are dead
- Brighter lighting than hallways

#### 5. Large Arena
- Circular, ~35m diameter, ~15m tall
- Curved walls with slight bowl slope at the base for surf-style movement
- 2-3 platform bridges at varying heights crossing the center
- Spawn points: 10-15 ground enemies, 4-6 flying enemy positions
- 2-3 waves of enemies
- Used less frequently than small arenas (1-2 per level max)
- Brightest lighting in the level

#### 6. Open Combat Room
- Rectangular, ~25m × 20m × 8m tall
- Scattered cover pillars (waist height — player can slide behind but not camp)
- Elevated walkways along 1-2 walls
- Entry and exit on different walls (not directly opposite — forces the player to traverse the room)
- Spawn points: 5-8 ground enemies, 1-3 flying positions
- No door lock — enemies are pre-placed, player can push through

#### 7. Vault Room (Optional Side Path)
- Small room branching off a hallway (side door, green-lit)
- Contains a reward pickup (placeholder item/chest for now)
- Guarded by 3-5 tougher enemies or a single miniboss placeholder
- Dead end — player must backtrack to the hallway
- Generate this 0-1 times per level

#### 8. Transition Piece
- Short connecting corridor (~8-10m)
- No enemies
- Serves as a breather between combat chunks
- Ammo pickups or small Pneuma top-off orbs here
- Visual cue: gold/amber lit doorway to signal "moving forward"

---

## Level Assembly

### Structure

A generated level follows this pattern:

```
[Entry] → [Hallway] → [Transition] → [Hallway or Open Room] → [Transition] → 
[Small Arena] → [Transition] → [Hallway] → [Hallway] → [Transition] → 
[Open Room or Small Arena] → [Transition] → [Hallway] → [Large Arena / Boss Arena]
```

### Rules

- Total chunks per level: 8-14 (targeting ~3-4 minutes of gameplay)
- Must start with a hallway segment (ease the player in)
- Must end with an arena (the level climax)
- No two arenas back to back (always at least one hallway/open room between)
- Hallways CAN be back to back (creates longer movement corridors — this is good)
- Include 1-2 vertical transition hallways per level for elevation changes
- Vault room spawns off a random hallway segment with a ~30% chance per level
- Every 5th level (5, 10, 15, 20, 25): end arena is replaced with a boss arena (larger, special geometry)

### Variation

- Generator picks from available chunks randomly within the rules
- Rotate and mirror chunks to increase perceived variety
- Randomize enemy spawn positions within chunks (use predefined spawn point sets, pick one per generation)
- Scale enemy count slightly per level (level 1 has fewer spawns per chunk, level 15 has more)

### Enemy Scaling Per Level

| Level Range | Ground Enemies (multiplier) | Flying Enemies (multiplier) |
|-------------|---------------------------|---------------------------|
| 1-5 | 1.0x | 0.5x (introduce slowly) |
| 6-10 | 1.3x | 1.0x |
| 11-15 | 1.5x | 1.3x |
| 16-20 | 1.8x | 1.5x |
| 21-25 | 2.0x | 2.0x |

---

## Enemy Spawn Setup

For now, use the existing enemy types. Place spawn points as Marker3D nodes within each chunk.

### Spawn Point Properties

- `@export var enemy_type: String = "ground"` (ground or flying)
- `@export var spawn_group: int = 0` (for wave-based arenas: 0 = pre-placed, 1 = wave 1, 2 = wave 2)
- Ground spawn points: on the floor
- Flying spawn points: 4-6m above floor level

### Arena Wave Logic

- Wave 0 (pre-placed): enemies exist when player enters
- Wave 1: spawns after wave 0 is ~50% cleared
- Wave 2 (large arenas only): spawns after wave 1 is ~50% cleared
- Brief audio cue when a new wave spawns (warning horn or similar)
- Doors unlock only after ALL waves are cleared

---

## Score / End of Level

When the player reaches the exit of the final arena:

- Display level complete screen with:
  - Time to complete
  - Enemies killed / total enemies
  - Accuracy percentage
  - Pneuma collected
  - Overall score (formula TBD — weight speed and kills heavily)
- Proceed to next level or return to hub

---

## Testing Priorities

After implementation, verify:

- [ ] Levels generate without overlapping geometry
- [ ] Player can traverse from entry to exit without getting stuck
- [ ] Wall jump surfaces are correctly oriented in hallways
- [ ] Arena doors lock/unlock properly with wave spawns
- [ ] Color palette makes geometry readable — can distinguish floor/wall/ceiling
- [ ] Grid texture on floors helps read movement speed
- [ ] Lighting guides the player toward exits
- [ ] Vault room spawns and is accessible
- [ ] Enemy count scales with level number
- [ ] Level feels roughly 3-4 minutes long at moderate skill
