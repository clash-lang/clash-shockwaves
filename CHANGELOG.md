## 1.0.1 - *11 May, 2026*

Shockwaves now supports Clash 1.10!

## v1.0.0 *07 Apr 2026*

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

## v0.0.1hd *04 Mar 2026*

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

## v0.0.0hsd *04 Mar 2026*

Initial release.
