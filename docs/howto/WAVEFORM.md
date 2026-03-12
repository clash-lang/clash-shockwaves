## How to write a custom Waveform instance
There are a number of times where you might have to write a custom instance of
`Waveform`. This guide will explain which functions need to be implemented,
and how to do so.

First, let's go through the functions and see what we need to do:

- `translator` is the most important function, as it produces the data that is used
   to determine how bits in the VCD file get translated. `addTypes` and `addSubtypes`
   are used to register these values. This will be covered at length.
- `width` is the bitwidth as reported by `BitSize` and should not be changed.
- Similarly, `typeName` does not need to be changed, unless you are writing an
  instance meant to be used as a `derive via`. In that case, use:
  ```hs
  instance Waveform (WaveformForX a) where
    typeName = typeNameP (Proxy @a)
  ```
- `styles` is for adding constructor styles, and will likely go
  unused in a fully custom instance. For a guide on
  using styles, look [here](STYLES.md).



### TRANSLATOR

The most important function of `Waveform` is `translator`: this specifies the `Translator`
that the waveform viewer should use to unpack and translate the binary values in the VCD
file. A `Translator` consists of two values: a width, denoting the number of bits the translator
is expected to receive, and a a `TranslatorVariant` that actually describes how these bits
are to be interpreted. There are many variants to choose from which are discussed below.



#### Constant values
If you have a constant value (such as a unit type or a constructor without fields), use
`TConst`. This is simply a constant translation value.

```hs
Translator 0 $ TConst $ Translation (Just (TODO,TODO,TODO)) [("sub",Translation (Just (TODO,TODO,TODO)) [])]
```

#### Sum types
If you have multiple constructors (a sum type), use `TSum`. This will by default not create
any subsignals, so you'll likely want to use `TDuplicate` for all subtranslators.
```hs
translator = Translator width $ TSum
  [ Translator width1 $ TDuplicate "Constr1" $ translatorForConstr1 
  , Translator width2 $ TDuplicate "Constr2" $ translatorForConstr2
  ]
```

Instead of creating the `TDuplicate` translator manually, you can also use the
`tDup` function:

```hs
translator = Translator width $ TSum
  [ tDup "Constr1" $ translatorForConstr1 
  , tDup "Constr2" $ translatorForConstr2
  ]
```

> **Note:** The sum translator will consume $clog(|translators|)$ bits, and pass the rest on to the chosen translator.

> **Note:** The `TDuplicate` translator uses the `WSInherit 0` style to copy the style of it's subvalue.
> The subvalue does not copy the style directly, as copying a style like `Inherit 2` would be problematic.

If the capabilities of `TSum` are insufficient, you might want to use `TAdvancedSum`. This translator
allows you to select the bits used to determine the variant, selects the translator based on ranges of values,
and passes all bits to the selected translator.


#### Product types
Next, if a constructor has fields (a product type), you can use `TProduct`.
This translator has a lot of options.

```hs
translator = Translator width $ TProduct
  { subs
  , start, sep, stop,
  , labels
  , preci, preco
  }
```

`subs` is a list of translators. The bits are split up and sent to these subtranslators,
and their translation values are used as subsignals and joined to form the toplevel value.

`start`, `sep` and `stop` are used to attach subsignal values together. If `labels`
is not empty, the values will be inserted before each subtranslator value - this is
often used for record-like data.
```
<start> <sub[0]> <sep> <sub[1]> <stop>
<start> <labels[0]> <sub[0]> <sep> <labels[1]> <sub[1]> <stop>
```
For example, a Haskell list would have `start="[",sep=",",stop="]",labels=[]` while
a record might look like `start="MyRecord{",sep=",",stop="}",labels=["field1=","field2=]`.

`preci` and `preco` denote the inner and outer operator precedence respectively. The precedence of the
subvalue translation is compared to the inner prescedence, and if this inner precedence is equal or higher,
the subvalue is wrapped in parentheses. The outer precedence is used for the final translation.
If your data type is joined using spaces (as is often the case), set both to `10`.
For custom operators, just use the operator precedence for both.
If values never need parentheses, use `preci=-1` and `preco=11`.
In a case like `fromList [<sub[0]>,<sub[1]>]` you'd want to use `preco=10` (because the value is joined by a space)
but `preci=-1` (since the list syntax isolates the subvalues, so they never need parentheses).

If `TProduct` is not flexible enough, you might want to use `TAdvancedProduct`. This translator
allows you to translate arbitrary slices of bits with translators, and then construct the value
and subsignals from these translations.

#### Arrays
If your datatype looks more like a homogeneous list, you'll likely want to use `TArray`
instead. It is basically a reduced version of `TProduct` that has a single subtype
and numbered subsignals.

```hs
translator = Translator width $ TArray
  { sub, len
  , start, sep, stop
  , preci, preco
  }
```

Here `sub` is a single translator, and `len` is the number of elements in the array.
The other fields all have the same functionality as they have in `TProduct`.

#### Other types
If you have a subvalue that needs to be translated, do not include its full translator,
but include a reference to the type using `TRef`. Instead of manually creating this value,
use the `tRef` function to create the full translator:
```hs
translator = tRef (Proxy @MyType)
```

#### Numbers
`TNumber` is used to translate integer types. It is used as `TNumber{format,spacer}`,
and more info about its behaviour can be found [here](NUMBER.md).

#### Lookup tables
`TLut` is used for LUT based types, and unless you _really_ know what you are doing,
you should not touch this translator. Information on using LUTs can be found [here](LUTS.md).

#### Adding custom styles
The style of a signal can be changed from the default by using the `TStyled` translator.
This translator applies the provided style to the toplevel render value created by its subtranslator,
provided the render value has the `WSDefault` style (so it does not overwrite `WSError`, for example!).

Like `tDup`, `tStyled` is the easiest way to change the style of a translator.

```hs
translator' = tStyled "red" translator
```

> **Note:** when opened in Surfer, style variables are replaced _before_ any translations
> take place. This means that `TStyled` will happily replace any style variable that
> resolves to `WSDefault`. However, when translating inside Haskell, the style variables
> are not resolved at all, and as such, will not be replaced either. This difference in
> behavior might cause unexpected behaviour when using LUTs under very specific circumstances.

#### Manipulating bits

Sometimes, the binary representation of a type does not allow for the translation you want.
If this is the case, it's by far the easiest to change to using LUTs. However, if you want
a more performant option, it might be possible to change the bits using the `TChangeBits`
translator.

'TChangeBits' has a field `bits` of type `BitPart` which defines what bits get passed on to the
translator included. 


#### Creating custom translator configurations
Although the translators must still process the bits correctly, a lot of
configuration is possible. For example, `Maybe a` would by default get a translator
like this:

```hs
translator = Translator (width @(Maybe a)) $ TSum
  [ tDup "Nothing" $ Translator 0 $ TConst $ Translation (Just ("Nothing",_,11)) []
  , tDup "Just" $ _ $ TProduct
      { subs = [(Just "0", tRef (Proxy @a))] 
      , start = "Just ", sep = "", stop = "", labels = []
      , preci = 10, preco = 10
      , style = 0 }]
```

Corresponding to the following structure:
```
signal     |{ Nothing }{ Just True }
|- Nothing |{ Nothing }
+- Just    |           { Just True }
   +- 0    |           { True      }
```

But instead, to reduce unnecessary subsignal clutter, it looks like this:

```hs
translator = Translator _ $ TSum
  [ Translator 0 $ TConst $ Translation (Just ("Nothing","$maybe_nothing",11)) []
  , Translator (width @a) $ TProduct
      { subs = [(Just "Just.0", tRef (Proxy @a))] 
      , start = "Just ", sep = "", stop = "", labels = []
      , preci = 10, preco = 10
      , style = 0 }]
```

This shows up as:
```
signal    |{ Nothing }{ Just True }
+- Just.0 |           { True      }
```

In general, the translators `TDuplicate` and `TStyled` can be inserted or removed
freely, since they do not influence how bits are interpreted, as can all styles and
precedence and text values.



### Conclusion

That's it! For some specific purposes of creating custom `Waveform` instances, see:
- [How to implement Waveform for GADTs](GADTS.md)
- [How to add extra information to your data types](EXTRA_INFO.md)
