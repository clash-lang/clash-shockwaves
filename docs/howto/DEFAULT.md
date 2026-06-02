## How to modify the default translator

There are a few modifications you can easily make to the translator that is
automatically derived for a data type, without doing a fully custom `Waveform`
implementation. These work by taking the default unstyled translator using `defaultTranslator`,
and then modifying it.

For applying styles, see [this guide](STYLES.md).

### ADDING CONSTRUCTOR STYLES

Styles can be added to different translators using `withConstructorStyles`.
This function takes a list of styles, and applies it to the different constructors
as they appear in the default translator.

By default, this is applied with the `constructorStyles` field in `Waveform`,
i.e.:

```hs
instance Waveform a where
  translator = ... $ withConstructorStyles (constructorStyles @a) $ defaultTranslator @a
```

This function overwrites the styles of styled constructors and constant translations.


### PROPAGATING SINGLE FIELD PRODUCT TYPE STYLES

Sometimes you have a data type or constructor that acts as a wrapper for other data
(constructors with exactly one field). In this case, it is often useful to propagate
the style of the embedded data, so any peculiarities surface without the need to
expand the subsignals of the constructor. This can be achieved by applying the `WSInherit 0`
style.

Instead of manually adding this style, you can call `inheritSingleFieldStyle` to do so
automatically. This is done by default in `Waveform`'s `translator` function:

```hs
instance Waveform a where
  translator = inheritSingleFieldStyle $ ... $ defaultTranslator @a
```

The function does not overwrite the styles of constructors that have been explicitly styled
already.


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
  translator = noConstructorSubsignals True $ defaultTranslator @MyType (constructorStyles @MyType)
  constructorStyles = ...
```

The first argument to `noConstructorSubsignals` determines whether or not to rename field subsignals.



### RENAMING FIELDS

You might want to rename the subsignals for fields of a data type - particularly, when you have
a non-record data type and the subsignals are just numbers.

For example, a data type `data Point = Point Int Int` would have subsignals `0` and `1`,
which you might want to be `x` and `y` instead.

In this case, you can use `renameFields`. Rename fields takes a list with for every constructor
a list of field names. Note that lengths of these lists must match the number of constructors and fields
exactly, or the function will error.

For example:

```hs
data Point = Point Int Int deriving (...)

instance Waveform Point where
    translator = renameFields [["x","y"]] $ defaultTranslator @Point []
```

Also note that this function will not rename the field names inside a record;
it only renames the subsignals that are created for these fields.
