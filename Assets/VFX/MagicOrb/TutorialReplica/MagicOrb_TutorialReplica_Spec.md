# Magic Orb Tutorial Replica Spec

Source: `C:/Users/lafa/Desktop/Unity VFX Graph - Magic Orb Effect Tutorial.mp4`.
Audio was transcribed locally with Whisper and checked against extracted tutorial frames.

## Exposed Properties
- `TrailsSpawnRate` float default `30`.
- `Color` color cyan-blue HDR-style base color.
- `TrailColor` color yellow final-variation trail accent.
- `Size` float default `1`.
- `TrailsLifetime` float default `1`.
- `ParticleSpawnRate` float default `50000` after tutorial increase.

## VFX Graph Systems
- Trails: constant spawn rate `30`, particle/strip capacity around `1000`, sphere spawn radius `Size * 1`, lifetime range `TrailsLifetime * 1..3`, turbulence, conform-to-sphere radius `Size * 1.5`, attraction `10`, stick force `5`, additive strip quad, size `Size * 0.01..0.02`, size over life tapers large to small.
- Beam: periodic burst count `1`, interval/delay `1`, lifetime `2`, default particle quad, additive, size `Size * 10`, base color divided visually by about `4`, alpha fades in and out over life.
- Core Particles: constant spawn rate exposed as `ParticleSpawnRate`, tutorial raises from `5000` to `50000`, sphere spawn radius `Size * 2`, velocity range `-0.5..0.5`, size `0.01..0.02`, turbulence, conform-to-sphere radius `Size * 2`, Perlin curl 3D based on position plus time, remap `[-6,6]` to `[-1,1]`, turbulence intensity and drag `5`.

## Isolation
- Built as `MagicOrb_TutorialReplicaRoot` in `MagicOrb_TestScene`.
- Existing `MagicOrbRoot`, `MagicOrb.vfx`, and `MagicOrbRig.cs` are not used as implementation inputs.
