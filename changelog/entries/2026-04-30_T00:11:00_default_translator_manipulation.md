---
issues: [50]
---

# ADDED
Function `defaultTranslator`, which returns the translator that is used
when deriving `Waveform`.

# ADDED
`noConstructorSubsignals` and `renameFields` can be used to manipulate the default
translator (made available through `defaultTranslator`).
`noConstructorSubsignals` creates the same translators that are used for `Maybe` and `Bool`.

These functions can be used to obtain some common non-default `Waveform` instances
more easily.
