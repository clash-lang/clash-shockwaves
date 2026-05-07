---
issues: [50]
---

# Modifying the default translator
It was already possible to set styles; now, it's also possible to easily modify
the structure of the automatically derived translator of a type without doing a
fully custom implementation! See [the new HOWTO guide](docs/howto/DEFAULT.md).

# ADDED
`defaultTranslator`, which returns the translator that is used when deriving `Waveform`.

# ADDED
`noConstructorSubsignals` and `renameFields` can be used to manipulate the default
translator (made available through `defaultTranslator`).
`noConstructorSubsignals` creates the same translators that are used for `Maybe` and `Bool`.
