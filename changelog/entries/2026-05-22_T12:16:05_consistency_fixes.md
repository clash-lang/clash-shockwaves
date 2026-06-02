---
issues: [112]
---

# CHANGED
Renamed `safeVal` and `safeValOr` to `safeNF` and `safeNFOr`.
`safeNF` now returns a `Maybe` value instead of an `Either` holding a potential error message.

# CHANGED
Renamed both `WaveformForLUT` and its constructor `WfLut` to `WaveformForLut`.

# CHANGED
Renamed `WfNum` to `WaveformForNumber`.

# CHANGED
Rename `styles` in `Waveform` to `constructorStyles`.

# CHANGED
Renamed `rFromVal` to `defaultRender`.

# REMOVED
Removed `tFromVal`.
