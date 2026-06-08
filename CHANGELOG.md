## v1.1.0 - *08 Jun, 2026*

### Consistency changes:
Shockwaves 1.1 includes a number of changes to make the library more internally consistent.
This mostly includes a number of renamed functions.

### Static LUTs:
Sometimes, you want the flexibility of a LUT,
but translating all values of a type is rather inefficient.
You can now create _static LUTs_, where you define the entire LUT yourself,
rather than building it up by translating values that pop up in simulation.

Please see the updated [HOWTO guide on using LUTs](docs/howto/LUTS.md) for more information!
[#92](https://github.com/clash-lang/clash-shockwaves/issues/92)

### Modifying the default translator:
It was already possible to set styles, but more advanced deviations from the default
required a completely custom implementation.
Shockwaves 1.1 introduces functions for obtaining the default translators for types,
as well as several function for modifying these, by adding constructor styles and
inheriting styles (both of which are used by default), but also renaming fields
and compacting the subsignal structure. See [the new HOWTO guide](docs/howto/DEFAULT.md).
[#50](https://github.com/clash-lang/clash-shockwaves/issues/50)

### More BitPart options:
With the new `BitPart` options, the `ChangeBits` translator has become a lot more
powerful. Beyond simply reordering bits, it is now possible to perform various operations
on bits. See [the updated documentation](docs/howto/ADVANCED.md) for more.
[#54](https://github.com/clash-lang/clash-shockwaves/issues/54)

### Surfer protection:
The Surfer translator extension now verifies the Shockwaves translators it's served.

Previously, incorrect custom `Waveform` instances could crash the extension,
taking Surfer down with it.
The new verification step checks for any major issues that would crash Surfer,
replacing any truly problematic translators, and also warns of (probably) incorrect
constructions such as translators that request more bits than they actually use.

For performance reasons, lookup tables are not checked, and values not matching the
reported structure might still cause crashes.
[#33](https://github.com/clash-lang/clash-shockwaves/issues/33)

### Added:
- `WaveformLUT` now has a method `staticL`.
  This method can be overwritten to define a static LUT,
  (which renders `translateL` and `structureL` obsolete).
  [#92](https://github.com/clash-lang/clash-shockwaves/issues/92)

- `defaultTranslator` returns the unstyled translator that is used when deriving `Waveform`.
  [#50](https://github.com/clash-lang/clash-shockwaves/issues/50)
- `withConstructorStyles` applies a list of styles to the constructors of a translator.
  [#124](https://github.com/clash-lang/clash-shockwaves/issues/124)
- `inheritSingleFieldStyle` applies the `Inherit 0` style to product translators with only one field.
  [#124](https://github.com/clash-lang/clash-shockwaves/issues/124)
- `noConstructorSubsignals` removes the constructor subsignals from a default translator.
  The resulting structure is like that of `Maybe` and `Bool`.
  [#50](https://github.com/clash-lang/clash-shockwaves/issues/50)
- `renameFields` can be used to rename the fields of a product type.
  [#50](https://github.com/clash-lang/clash-shockwaves/issues/50)

- `Bits` instance for `BitList`.
  [#114](https://github.com/clash-lang/clash-shockwaves/issues/114)
- `BitList.length` returns a `BitList`'s length.
  [#114](https://github.com/clash-lang/clash-shockwaves/issues/114)
- `BitList.hasUndefined` returns whether a `BitList` has any undefined bits.
  [#114](https://github.com/clash-lang/clash-shockwaves/issues/114)

- New `BitPart` options: (`BP`)`HasUndefined`, `Reverse`, `Invert`, `And`, `Or`, `Xor`, `OneHot`, `NHot` and `If`.
  [#54](https://github.com/clash-lang/clash-shockwaves/issues/54)
- Added the configuration option `override_number_format` to the Surfer extension, which lets you set the format of all numbers.
  [#115](https://github.com/clash-lang/clash-shockwaves/issues/115)

- `bitSize` returns the number of bits based on the `BitSize` class.
- `defaultTypeName` derives a unique name automatically for a type.
  The name consists of the simple type name plus a hash to prevent name collisions.
  [#111](https://github.com/clash-lang/clash-shockwaves/issues/111)
- `pprintT` prints a translator's structure, and can be used for debugging purposes when creating custom translators.


### Changes:
- `TLut` now has a field for the optional static LUT.
  [#92](https://github.com/clash-lang/clash-shockwaves/issues/92)
- `tLut` has been renamed to `tGeneratedLut`, and `tStaticLut` has been added.
  A new `tLut` function switches between the two.
  [#92](https://github.com/clash-lang/clash-shockwaves/issues/92)
- `hasLut` has been renamed to `hasGeneratedLut`.
  [#92](https://github.com/clash-lang/clash-shockwaves/issues/92)

- Renamed `BitList.binPack` and `BitList.binUnpack` to `BitList.pack` and `BitList.unpack`.
  [#114](https://github.com/clash-lang/clash-shockwaves/issues/114)

- The functions `tRef`, `tLut` (and the new `tStaticLut` and `tGeneratedLut`) no longer take proxy arguments.
  [#111](https://github.com/clash-lang/clash-shockwaves/issues/111)

- Swapped the order of the `TChangeBits` constructor fields to be easier to use without record syntax.

- `Bit` now uses a static LUT. It is displayed as `0`/`1`/`x`, and styles can be
  controlled through style variables `bit_low` and `bit_high`.
  [#92](https://github.com/clash-lang/clash-shockwaves/issues/92)
- `BitVector` now contains subsignals for all bits.
  The toplevel value is still generated by a number translator, and as such, may be modified through config files.
  [#48](https://github.com/clash-lang/clash-shockwaves/issues/48)

- Renamed `safeVal` and `safeValOr` to `safeNF` and `safeNFOr`.
  `safeNF` now returns a `Maybe` value instead of an `Either` holding a potential error message.
  [#112](https://github.com/clash-lang/clash-shockwaves/issues/112)
- Renamed both `WaveformForLUT` and its constructor `WfLut` to `WaveformForLut`.
  [#112](https://github.com/clash-lang/clash-shockwaves/issues/112)
- Renamed `WfNum` to `WaveformForNumber`.
  [#112](https://github.com/clash-lang/clash-shockwaves/issues/112)
- Rename `styles` in `Waveform` to `constructorStyles`.
  [#112](https://github.com/clash-lang/clash-shockwaves/issues/112)
- Renamed `rFromVal` to `defaultRender`.
  [#112](https://github.com/clash-lang/clash-shockwaves/issues/112)

- To prevent issues, the translators specified for types must consume the same number of bits
  as are used to represent the data (as specified by `BitSize`).
  `tRef` now includes a check for this,
  which prevents types with incorrect widths both from being referenced and used directly.
  [#126](https://github.com/clash-lang/clash-shockwaves/issues/126)



### Fixes:
- VCD files generated by Shockwaves now contain both the Clash and Shockwaves version,
  which was previously not properly implemented yet.
  [#37](https://github.com/clash-lang/clash-shockwaves/issues/37)

### Deprecated:
- `width` has been deprecated from the `Waveform` class.
  Instead, use `bitSize`.

### Removed:
- Removed `tFromVal`.
  [#112](https://github.com/clash-lang/clash-shockwaves/issues/112)

## v1.0.1 - *11 May, 2026*

Shockwaves now supports Clash 1.10!

## v1.0.0 - *07 Apr, 2026*

The first official full release!

Since the 0.0 release, a lot of things have been changed and fixed.
Furthermore, many changes were made behind the scenes to make the project more maintainable.
The system is now fully usable with no (known) bugs,
but more features and improvements are already on their way!

### Added:
- Added several options for rendering numbers.
  [#52](https://github.com/clash-lang/clash-shockwaves/issues/52)
  [#49](https://github.com/clash-lang/clash-shockwaves/issues/49)
  [#62](https://github.com/clash-lang/clash-shockwaves/issues/62)
- Added HOWTO guides on using the advanced translators (advance sum/product, bitchange)
  and precedence values, as well as notes on differences between translations in Haskell
  and Surfer.
  [#51](https://github.com/clash-lang/clash-shockwaves/issues/51)
  [#59](https://github.com/clash-lang/clash-shockwaves/issues/59)
  [#45](https://github.com/clash-lang/clash-shockwaves/issues/45)
- Linked the HOWTO guides on GitHub in the Haddock documentation.
- A permanent downloads of the Surfer extension is now available on the GitHub release page.

### Changed:
- Renamed the `shockwaves` library to `clash-shockwaves`, and `surfer_shockwaves` to `surfer-shockwaves` to match.
  [#70](https://github.com/clash-lang/clash-shockwaves/issues/70)
- Adding a config file is now part of the setup guide too.
  The provided config file has some good defaults, and immediately improve the user experience
  without the need to actually go into the configuration options.
- Made the unknown style var log message a less alarming warning.
  After all, having missing style variables is expected.
  [#73](https://github.com/clash-lang/clash-shockwaves/issues/73)
- Changed the `BitPart` `BPSlice` option to slice from a different `BitPart`'s output instead of the input,
  and added `BPIn` to refer to the input.
  Part of [#54](https://github.com/clash-lang/clash-shockwaves/issues/54)
- The clock, reset and enable signals are now visible in their non-alarming states
  (reset deasserted, enable on). The default config makes these less obtrusive.
  [#78](https://github.com/clash-lang/clash-shockwaves/issues/78)
- The source code is now formatted using Fourmolu.

### Fixed:
- When (advanced) sum translators have multiple translators that generate subsignals with the same name,
  these are now merged recursively, instead of being added separately.
  [#36](https://github.com/clash-lang/clash-shockwaves/issues/36)
- Replaced several instances of `unknown` with `undefined`.
  [#47](https://github.com/clash-lang/clash-shockwaves/issues/47)
- `CLASH_OPAQUE` annotations have been replaced with `OPAQUE`.
  [#72](https://github.com/clash-lang/clash-shockwaves/issues/72)
- Made the code compatible with the stack LTS-23.28 resolver (GHC 9.8.4).

## v0.0.1hd - *04 Mar, 2026*

### Added:
- Added proper links and instructions for adding dependencies to the setup HOWTO guide.
  [#41](https://github.com/clash-lang/clash-shockwaves/issues/41)
  

### Changed:
- Loosened clash version constraints to allow versions 1.8.2 and 1.8.3.
  [#40](https://github.com/clash-lang/clash-shockwaves/issues/40)

### Fixed:
- After renaming `traceMap#` to `maps#`, an annotation was left; this has been fixed.
  [#39](https://github.com/clash-lang/clash-shockwaves/issues/39)
- `Maybe` accidentally used style variable `$maybe_just` instead of `maybe_just`.
  [#38](https://github.com/clash-lang/clash-shockwaves/issues/38)

## v0.0.0hsd - *04 Mar, 2026*

Initial release.
