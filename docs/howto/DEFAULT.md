## How to modify the default translator

There are a few modifications you can easily make to the translator that is
automatically derived for a data type, without doing a fully custom `Waveform`
implementation. These work by taking the default translator using `defaultTranslator`,
and then modifying it.

For applying styles, see [this guide](STYLES.md).

### A MORE COMPACT FORMAT

The default translator structure was designed to work well even with complex data types,
but sometimes simpler data types benefit from a less verbose structure.
Examples of this are `Maybe` and `Bool`.

You can choose not to have subsignals for the constructors of a type (with multiple constructors).
For types like `Bool`, which do not have fields in their constructors, this simply gets rid
of subsignals alltogether. For a type like `Maybe`, it means the subsignal for `Nothing` is
removed, while the subsignal for `Just` is replaced by its subsignal for the contained value (`0`).
For clarity, you can have the system rename these fields to be prefixed by their constructor name:
for `Maybe`, the `0` subsignal is renamed to `Just.0`.

To remove constructor subsignals, use `noConstructorSubsignals` on the `defaultTranslator` like this:

```hs
instance Waveform MyType where
  translator = noConstructorSubsignals True $ defaultTranslator @MyType (styles @MyType)
  styles = ...
```

The first argument to `noConstructorSubsignals` determines whether or not to rename field subsignals.



### RENAMING FIELDS

You might want to rename the subsignals for fields of a data type - particularly, when you have
a non-record data type and the subsignals are just numbers.

For example, a data type `data Point = Point Int Int` would have subsignals `0` and `1`,
which you might want to be `x` and `y` instead.

In this case, you can use `renameFields`. Rename fields takes a list with for every constructor
a list of field names. Note that lengths of these lists must match the number of constructors and fields
exactly, or the resulting translator will be broken.

For example:

```hs
data Point = Point Int Int deriving (...)

instance Waveform Point where
    translator = renameFields [["x","y"]] $ defaultTranslator @Point []
```
