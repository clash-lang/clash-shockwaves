# Shockwaves Haskell Library

This is the Haskell library for Shockwaves, a typed waveform solution designed for Clash.

The basic concept of the library is that for all types for which signals exist in simulation,
the `Waveform` class is implemented. This class provides all the functionality needed to provide
metadata about types when simulating. This metadata is stored separately, and can be used
by the waveform viewer to reconstruct a typed representation in the waveform viewer.

By default, `Waveform` uses `Generics` to derive a waveform viewer representation similar
to `Show`. Types with multiple constructors and constructors with fields get subsignals.

The `Waveform` class can of course be customized. This allows for more advanced control over
the way data is represented in the waveform viewer. Particularly, through `WaveformLUT`,
translations can be implemented as lookup tables, allowing for arbitrary code execution
in Haskell to create whatever data is desired.

The library includes a modified version of `Clash.Signal.Trace` that uses `Waveform` to
generate metadata.



## Default behaviour

The default implementations of Waveform make several "clever" choices in how to display values.

For types with multiple constructors and fields, subsignals are created per constructor,
and for each constructor, subsignals are created for each of its fields.
Constructor subsignals are labeled with the name of the constructor,
and field subsignals with the field names.
If there are no field names, the subsignals are numbered instead.
The value displayed at the toplevel is the same as that of the current constructor.

If a type has only one constructor, there is no need for subsignals for the constructor.
Instead, the subsignals for the fields added to the toplevel signal directly.

If a constructor has exactly one field, it will by default copy the style of the contained value.

If a constructor is an operator and has exactly two fields, the constructor will be rendered as
and infix. The operator precedence is used to appropriately add parentheses in nested values.
If an operator constructor has a different number of fields, it is parenthesized and used as normal.

Values are always rendered according to the information actually stored in the binary representation.
This means the system will render both `(undefined,undefined)` and `undefined` as `(undefined,undefined)`:
since there is only one constructor, the value can only be that constructor, and this is known
regardless of whether the value was actually `unknown` during code execution or not.
The translation functions provided in the library, which are meant for creating LUT-based translations,
mimic this behaviour.

Shockwaves has several waveform styles, some of which are special.
If a translation has the `WSError` style, this is propagated through all signals above.
This style is used for undefined values.
`WSWarn` is displayed in the same manner, but not propagated.



# Tutorial

This sections contains instructions for some common uses of Shockwaves.

## Derive Waveform

The easiest way to use Shockwaves is to simply derive the `Waveform` class for all types
that appear in the output. This requires `Generic` and `Typeable` to also be derived.

## Adding coloured constructors

It might be useful to mark the different constructors of a type using various colors.
To do this, one simply needs to do a custom implementation of Waveform where `styles`
is overwritten with a list of waveform styles, in the order that the constructors appear.

## Custom Waveform instances

For more advanced topic, please see the [HOWTO guides](../docs/howto/README.md).