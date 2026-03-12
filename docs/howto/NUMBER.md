## How to implement Waveform for integer-like types
You may be using integer number types that are not yet supported by Shockwaves,
and find yourself unable to derive a proper `Waveform` instance for your data type.
Luckily, in this case you do not need a fully custom implementation of `Waveform`.

Say you have some data type `MyInt` that you want to display.
Then you can derive `Waveform` via `WaveformForNum`!

```hs
import ...
data MyNum = ...
  deriving via WaveformForNum format spacer MyNum instance Waveform MyNum
```

As you can see, for using `WaveformForNum`, we need to provide some extra types.
The first one, `format`, determines what you want your number to be translated into:
- `NFSig` for signed decimal numbers (using two's complement)
- `NFUns` for unsigned decimal numbers
- `NFBin` for binary numbers
- `NFOct` for octal numbers
- `NFHex` for hexadecimal numbers

The second one is a spacer. Since large numbers may be difficult to read,
Shockwaves has the option to add spacer strings every few characters. For
example, the number `123456` may be displayed as `123_456` instead.

`Maybe (Int,String)`
If you do not want any spacers, you can use `'Nothing`. Otherwise, this provides
the string to insert and the number of digits between occurances.

For example, if we want out `MyNum` to have digits grouped by hundreds instead of thousands,
we may write:

```hs
...
  deriving via (WaveformForNum NFUns ('Just '(2,"_")) MyNum) instance Waveform MyNum
```

Some default spacers are defined. `NoSpacer` is the same as `'Nothing`.
`DecSpacer` is the default for decimal numbers and places a `_` every 3 digits;
`BinSpacer`, `OctSpacer` and `HexSpacer` place a `_` every 8, 4 and 2 digits respectively.

**Note:** The spacer configuration can be overwritten globally per number format!
Check [TODO:link] for more.

### More control

By default, numbers will use the error style if bits are undefined,
and non-decimal numbers get prefixes (`0b`,`0o`,`0X`).

By creating a normal `Waveform` instance in which `translator` is overwritten
by a `TNumber` translator, it's possible to change this. For example:

```hs
instance Waveform (BitVector n) where
  translator = Translator (width @(BitVector n))
    $ TNumber
      { format = NFBin
      , spacer = Nothing
      , prefix = ""
      , warn = True
      }
```
