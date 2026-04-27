# Holo FX Quick Start (URP)

## 1) Texture import settings

- `BaseColor`: keep default (`sRGB On`).
- `NormalMap`: set `Texture Type = Normal map`.
- `Mask` (`R:Metallic G:AO B:Emission A:Roughness`):
  - `sRGB (Color Texture) = Off`
  - keep all 4 channels.

## 2) Scene hierarchy

- Create `HoloFXRoot` under your crate.
- Add child `TopPlane` (thin plane on the top opening).
  - Material shader: `ShaderCourse/Holo/HoloTopSurface`
- Add child `VolumeBox` (thin box volume above top plane).
  - Material shader: `ShaderCourse/Holo/HoloVolumeBeams`

## 3) Material texture assignment

- `TopPlane` material:
  - `_HoloBaseMap` = BaseColor
  - `_HoloNormalMap` = NormalMap
  - `_HoloMaskMap` = Mask
- `VolumeBox` material:
  - `_MaskMap` = Mask (optional but recommended for logo-linked beams)

## 4) Recommended starting values

### TopPlane (`HoloTopSurface`)

- `_EmissionIntensity`: `4.5`
- `_EdgeBoost`: `1.8`
- `_FresnelPower`: `3.2`
- `_ScanTiling`: `24`
- `_ScanSpeed`: `1.6`
- `_ScanWidth`: `0.2`
- `_Alpha`: `0.85`

### VolumeBox (`HoloVolumeBeams`)

- `_Intensity`: `5.5`
- `_BeamDensity`: `9`
- `_BeamFill`: `0.42`
- `_BeamWidth`: `0.14`
- `_TopFadeStart`: `0.62`
- `_TopFadeSoftness`: `0.3`
- `_UseMaskMap`: `1`
- `_MaskInfluence`: `0.65`

## 5) Bloom guidance

- Enable URP Bloom in your Volume.
- Suggested range:
  - Threshold: `0.8 - 1.1`
  - Intensity: `0.9 - 1.6`
  - Scatter: `0.55 - 0.75`

Tune bloom after material intensity is stable.
