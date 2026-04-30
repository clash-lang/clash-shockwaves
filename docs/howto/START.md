


## How to get typed waveforms

Shockwaves has to output additional type information alongside the VCD output.
For this to work, you need to do two things:
- specify how types are shown in the waveform viewer
- trace signals using the `Clash.Shockwaves.Trace` library

Let's first take a look at tracing.

### TRACING
This is what a typical usage of `Clash.Signal.Trace` looks like:

```hs
import Clash.Prelude hiding (writeFile)
import Data.Text.IO  (writeFile)

counter :: SystemClockResetEnable => Signal System (Unsigned 16)
counter = register 0 (counter + 500)

main :: IO ()
main = do
  let cntrOut = exposeClockResetEnable counter systemClockGen systemResetGen enableGen
  vcddata <- dumpVCD (0, 100) (traceSignal "counter" cntrOut) []
  case vcddata of
    Left msg ->
      error msg
    Right vcd ->
      writeFile "waveform.vcd" vcd
```

The code for `Clash.Shockwaves.Trace` is very close: instead of creating only producing a VCD file,
the function also creates a JSON object containing all of the translation information.

```hs
import Clash.Prelude hiding (writeFile, dumpVCD, traceSignal)
import Data.Text.IO  (writeFile)
import Clash.Shockwaves

counter :: SystemClockResetEnable => Signal System (Unsigned 16)
counter = register 0 (counter + 500)

main :: IO ()
main = do
  let cntrOut = exposeClockResetEnable counter systemClockGen systemResetGen enableGen
  vcddata <- dumpVCD (0, 100) (traceSignal "counter" cntrOut) []
  case vcddata of
    Left msg ->
      error msg
    Right (vcd,meta) ->
      do writeFile     "waveform.vcd"  vcd
         writeFileJSON "waveform.json" meta
```

If we now run the `main` function, we get the files `waveform.vcd` and `waveform.json`. Opening the
VCD file in Surfer, this is what the result looks like:

![counter signal: 0, 500, 1_000, 1_500, ...](start/unsigned.png)

Though it may not look like much, the underscores show we are indeed looking at a Shockwaves translation!

> **IMPORTANT:** The JSON file must have the same base filename as the VCD file! Otherwise, Shockwaves
> does not know where to look for it.



### CUSTOM DATA TYPES
This is great and all, but what if we want to use our own data types?

Imagine we have the following code

```hs
data Led = Red | Green | Blue
  deriving (Generic,Typeable,BitPack,NFDataX)

disco :: SystemClockResetEnable => Signal System Led
disco = register Red $ next <$> disco
  where next Red   = Green
        next Green = Blue
        next Blue  = Red

main :: IO ()
main = do
  let discoOut = exposeClockResetEnable disco systemClockGen systemResetGen enableGen
  vcddata <- dumpVCD (0, 100) (traceSignal "disco" discoOut) []
  case vcddata of
    Left msg ->
      error msg
    Right (vcd,meta) ->
      do writeFile     "waveform.vcd"  vcd
         writeFileJSON "waveform.json" meta
```

If we try to run this, we get:
```
No instance for ‘Waveform Led’
  arising from a use of ‘traceSignal’
```

`Waveform` is the class that allows Shockwaves to render data types. It specifies exactly
how a type should be translated. To be able to trace our data type `Led`, we need to create a
`Waveform` instance.

Luckily, in most cases `Waveform` can be derived directly! Deriving `Waveform` uses `Generic`
to create subsignals for constructors and data fields.

If we add `Waveform` to our type:
```hs
data Led = Red | Green | Blue
  deriving (Generic,Typeable,BitPack,NFDataX,Waveform)
```
and run the code again, it should now compile and run. Opening the file in `Surfer`, we see:

![signal showing Red, Green, Blue with subsignals for each constructor](start/disco.png)

That's it! Using this method, you can trace _almost_ all data types.

In cases where such a derivation fails, you might want to use one of the following resources:
- [How to implement Waveform for constant value types](CONSTANT.md)
- [How to implement Waveform for integer-like types](NUMBER.md)
- [How to write a custom Waveform instance](WAVEFORM.md)
- [How to implement Waveform for GADTs](GADTS.md)
- [How to add translations for difficult to unpack types](LUTS.md)

If you want to customize the behaviour, you can use one of these resources:
- [How to use colors to improve clarity](STYLES.md)
- [How to modify the default translator](DEFAULT.md)
- [How to add extra information to your data types](EXTRA_INFO.md)

Some other things you can do with Shockwaves:
- [How to add clock and other domain signals](DOMAINS.md)
- [How to customize Shockwaves behaviour](CONFIG.md)

