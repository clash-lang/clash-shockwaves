
# File format

Shockwaves uses a JSON file to store the translation data. The file has the
following structure:

```
{
    "signals": {
        "<signal>": "<type>",
        ...
    },
    "types": {
        "<type>": <translator>,
        ...
    },
    "luts": {
        "<lut>": {
            "<binary>": <translation>,
            ...
        },
        ...
    }
}
```

The `signals` key stores the type of each signal. `types` stores the translators
of all types. `luts` stores the lookup tables.

`<signal>` denotes a signal path, i.e. `module.submodule.signal`. This path
must match the structure in the VCD file. Standard tracing will result in
`logic.<trace name>`.

`<type>` is a unique identifier for the type. Shockwaves generates these in the
form `<fingerprint>: <human readable>`.

`<lut>` is an identifier for the LUT, and will usually just be the type
identifier.

`<binary>` is the raw VCD value, consisting of the characters `10x`.

### Translations

`<translation>` is a translation. It takes the format `[<render>,<subs>]` where
`<render>` is either `null` or `["<label>",<style>,<prec>]`. `<label>` is the
text to be displayed. `<prec>` is a number from 0 to 11 denoting the operator
precedence.
`<style>` is the wavestyle:
- `"D"` for default
- `"E"` for error
- `"H"` for hidden
- `{"I":<n>}` for inherited styles
- `"N"` for normal
- `"W"` for warn
- `"U"` for undefined
- `"Z"` for high impedence
- `"X"` for don't care
- `"Q"` for weak
- `{"C":[<R>,<G>,<B>,<A>]}` for custom colors - `<R>`,`<G>`,`<B>`,`<A>` are all
  8-bit unsigned values, and `<A>` is usually fixed to `255`.
- `{"V":[<var>,<default>]}` for configurable style variables

`<subs>` is a list of subsignal translations taking the form `[["<sub>",<translation>],...]` where `<sub>` is the subsignal name.


### Translators

A translator looks like `[<bits>,<variant>]`. Here `<bits>` denotes the number
of bits parsed by the translator, and `<variant>` the translator variant.

There are many translator variants available:

- `{"R":"<type">}`: a reference to another translator
- `{"L":"<lut>"}`: a reference to a lookup table.
- `{"S":[<translator>,...]}`: a sum type where the translator is picked base on the most significant bits.
- `{"S+":{...}}`: a more advanced sum type
  - `"i":[<from>,<to>]`: the slice of the data to use for indexing
  - `"d":<trans>`: the default translator
  - `"t":[[[<from>,<to>],<trans>],...]`: a list or index ranges and the translators to use for them
- `{"P":{...}}`: a product type. The keys are as follows:
  - `"t":[<sub>,<translator>]`: a list of translators used to parse consecutive blocks of bits. If `<sub>` is omitted, no subsignal is created.
  - `"[":"<start>"`: the opening string
  - `",":"<sep>"`: the separator string
  - `"]":"<stop>"`: the terminating string
  - `"n":["<label>",...]`: a list of labels to insert before values (may be omitted)
  - `"p":<prec>`: the precedence to compare subsignal values to
  - `"P":<prec>`: the precedence of the output
  - `"s":<index>`: the index of the signal whose style to copy. `-1` to disable.
- `{"P+":{...}}`: a more advanced product type
  - `"t":[[[<from>,<to>],<trans>],...]`: a list of slices and the translators to translate them with
  - `"h":[[<sub>,<i>]]`: a list of subsignals and the index in `t` to use for translations
  - `"v":[<valuepart>,...]`: a list of values to construct the value
  - `"P"`: the outer precedence 
- `{"A":{...}}`: an array of multiple values of the same type. The keys are as follows:
  - `"t":<translator>`: the translator to use for the contained values.
  - `"l":<len>`: the number of values in the array.
  - `"[":"<start>"`: the opening string
  - `",":"<sep>"`: the separator string
  - `"]":"<stop>"`: the terminating string
  - `"p":<prec>`: the precedence to compare subsignal values to
  - `"P":<prec>`: the precedence of the output
- `{"N":{...}}`: an integer number.
  - `"f":<format>` `<format>` can be:
    - `"U"`: unsigned
    - `"S"`: signed
    - `"H"`: hexadecimal
    - `"O"`: octal
    - `"B"`: binary
  - `"s":[<digits>,<text>]`: a the spacer to use (the string `<test>` every `<digits>` digits).
    `null` if no spacer should be inserted.
  - `"p":<prefix>`: the prefix to use (for example, `0b` for binary numbers)
  - `"w":<warn>`: bool indicating whether the warning style should be used rather than the
    error style if one or more bits are undefined.
- `{"D":["<sub>",<translator>]}`: put the output of `<translator>` in subsignal `<sub>` and copy its value.
- `{"X":[<style>,<translator>]}`: apply a style to the output of `<translator>`.
- `{"C":<translation>}`: a constant translation value.
