## How to use colors to improve clarity
Color can be an incredible visual aid. Shockwaves allows you to add colors through
`WaveStyles`. This guide will show you how to use `WaveStyles`, and how to apply them
to data constructors.

Let's assume we are working on a simple CPU that has several arithmetic instructions.
We would like to be able to mark these instructions with some colors: addition in green,
subtraction in red, multiplication in blue and division in purple.

```hs
data Instr = Add | Sub | Mul | Div
-- green red blue purple
```

### PICKING A WAVESTYLE
There are a number of standard styles to pick from, corresponding to different
VCD value types:
- `WSDefault`: The default style. Gets overwritten by the `TStyled` translator and does nothing when adding to the `styles` list in `Waveform`.
- `WSError`: An error. This looks the same as `WSWarn`, but is propagated upwards through the hierarchy.
- `WSHidden`: Do not display the style at all.
- `WSInherit`: Inherit the style of the n-th subsignal.
- `WSNormal`: The default of Surfer, explicitly.
- `WSWarn`: A warning.
- `WSUndef`: An undefined value. Looks the same as `WSWarn` and `WSError`.
- `WSHighImp`: A high impedance value.
- `WSDontCare`: A value that does not matter.
- `WSWeak`: A weakly driven value.

> **Note:** There is a subtle difference between using `Nothing` as a render value, and the `WSHidden` style.
> The hidden values can still be read, while reading from a `Nothing` value produces errors.

```hs
import Clash.Shockwaves.Waveform
style = WSWarn
```

The actual appearance of these styles will change depending on your selected Surfer theme.
However, these do not include the exact colors we want, we are better off using a custom style:

- `WSColor c`

There are multiple ways of creating a color value. First of all, you can directly
specify the color as an 8-bit RGB value:
```hs
import Clash.Shockwaves.Style
style = WSColor (RGB 255 0 0)
```

It is also possible to use the predefined colors in `Data.Colour.Names`, which is exported
in `Clash.Shockwaves.Style.Colors`, but since these are defined using real values,
they need to be converted first. You can make a `WaveStyle` directly using the `wsColor`
function:

```hs
import Clash.Shockwaves.Style
import Clash.Shockwaves.Style.Colors (red)
style = wsColor red
```

Alternatively, when using `OverloadedStrings`, you can specify the color name as a `String`
directly:

```hs
{-# LANGUAGE OverloadedStrings #-}
import Clash.Shockwaves.Waveform
style = "red"
```

It is also possible to specify the string as a hexadecimal value:
```hs
{-# LANGUAGE OverloadedStrings #-}
import Clash.Shockwaves.Waveform
style = "#f00"
```

Finally, it is possible to use _style variables_ that are defined in a configuration file (see [this guide](CONFIG.md)).
If the variable cannot be found, the second argument (default value) is used.
```hs
import Clash.Shockwaves.Waveform
style = WSVar "myRed" $ WSWarn
```
It is also possible to get a variable from a string, in which case `WSNormal` is taken
as the default value:
```hs
{-# LANGUAGE OverloadedStrings #-}
import Clash.Shockwaves.Waveform
style = "$myRed"
```


**IMPORTANT:** There exists one more wavestyle: `WSError`. This style is meant for
`undefined` values, and gets propagated upwards in the signal tree all the way to the
topmost signal.

### ADDING WAVESTYLES TO THE DATA TYPE
Now it is time to add the wavestyles we picked to the design.
Since marking constructors is a common usecase, constructor colors were added
to the default derivation of `Waveform`. All we need to do is create a `Waveform`
instance and overwrite the `styles` list:

```hs
data Instr = Add | Sub | Mul | Div deriving (...)
instance Waveform Instr where
  styles = ["green", wsColor red, "#11f", WSColor (RGB 100 0 255)]
```
