
## How to implement Waveform for GADTs
GADTs can be rather annoying to work with, since they do not allow the derivation of `Generic`.
This means you will either need to go the lazy route and use (lookup tables)[LUTS.md];
or do a fully custom implementation of `Waveform`. This guide expects you to already know
how to do custom `Waveform` implementations (see [this guide](WAVEFORM.md)),
and discusses two ways to deal with GADTs in particular.

### OPTION 1: DO ALL OF IT AT ONCE
The first option is to disregard the GADTs structure in implementation and look at the
abstract data type instead. This type may be easier to translate than the actual GADTs.
A good example of this is `Vec`: while it would be possible to create instances for `Cons`
and `Nil`, this is far more cumbersome (and would result in far less clear subsignals)
than by simply looking at `Vec` as a list.

This method depends heavily on what you are trying to achieve, and what subtypes your
constructors have. We will go through the implementation of `Vec` in here.

This is the `Waveform` instance for `Vec` inside `Clash.Shockwaves.Internal.Waveform`:

```hs
instance (KnownNat n, Waveform a) => Waveform (Vec n a) where
  translator = Translator (bitSize @(Vec n a)) $ if natVal (Proxy @n) /= 0 then
    TArray
      { start = ""
      , sep = " :> "
      , stop = " :> Nil"
      , preci = 5
      , preco = 5
      , len = fromIntegral $ natVal (Proxy @n)
      , sub = tRef @a
      }
    else
      TConst $ Translation (Just ("Nil",WSNormal,11)) []
```

The implementation completely discards the notion of `Cons` and `Nil` constructors,
and simply treats the array as a list with known length.

We just have to defined a `translator`. The most suitable translator for a lsit of values
is `TArray`, so we use that. For the edge case where the vector is empty, a constant value
is used instead.


### OPTION 2: SPLIT THE WAVEFORM CLASS
A different method it to split up implementations per constructor by creating a
an extra class that selects the constructor at the type level. An example of this is
`RTree`, which has the constructors `LR` and `BR`. At the type level, _we_ already know
which one of these constructors is going to be used, but the compiler does not.

We can create a helper class `WaveformRTree` which takes care of the different constructors
of `RTree`, and select the implementation based on a type-level check (`RTreeIsLeaf`).

```hs
type family RTreeIsLeaf d where
  RTreeIsLeaf 0 = True
  RTreeIsLeaf d = False

class WaveformRTree (isLeaf::Bool) d a where
  translatorRTree :: Translator
```

Now we can write the instances for leaves and branches. Let's start with the leaves,
and make them invisible (i.e. a leaf is rendered as it's containing data).

```hs
instance (Waveform a) => WaveformRTree True 0 a where
  translatorRTree = tRef @a
```

The branch translator is slightly more complex. Since `RTree` is usually rendered like
`<<a,b>,<c,d>>` we'll just keep to that structure using a product translator:
Note how to do this, `Waveform` must be implemented for the smaller subtrees -
something that is impossible for the leaf nodes.

```hs
instance (Waveform (RTree d1 a), Waveform a, d ~ d1 + 1, KnownNat d, KnownNat d1)
  => WaveformRTree False d a where
  translatorRTree = Translator (bitsize @(RTree d a)) $ TProduct
      { start = "<"
      , sep = ","
      , stop = ">"
      , labels = []
      , preci = -1
      , preco = 11
      , subs = [("left",tsub),("right",tsub)]
      }
    where tsub = tRef @(RTree d1 a)
```

> Note: it would be a bit more efficient to use `TArray` here; however, we would not be able to
> assign the subsignal names `"left"` and `"right"`.


And just like that, we can translate our GADT type!
