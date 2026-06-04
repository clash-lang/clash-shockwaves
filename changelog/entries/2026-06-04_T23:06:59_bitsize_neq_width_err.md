---
issues: [126]
---

# CHANGED
To prevent issues, the translators specified for types must consume the same number of bits
as are used to represent the data (as specified by `BitSize`).
`tRef` now includes a check for this,
which prevents types with incorrect widths both from being referenced and used directly.
