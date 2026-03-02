{-|
Copyright  :  (C) 2025-2026, QBayLogic B.V.
License    :  BSD2 (see the file LICENSE)
Maintainer :  QBayLogic B.V. <devops@qbaylogic.com>
Module      : Clash.Shockwaves.Style
Description : Shockwaves tools for styling signals

Everything needed to add different styles to the waveform viewer.

Waveforms can be styled in a number of ways. Various standard styles are provided
in 'WaveStyle'. It is also possible to use custom colors using 'WaveStyle.WSColor'.
These values can be provided in 3 typical ways:

- Directly from an @RGB Word8@ value, using the 'WSColor' constructor: 
  @WSColor (RGB 128 128 0)@.
- From a @Colour Double@ value, using the function 'wsColor'.
  Many such values are provided in "Clash.Shockwaves.Style.Colors".
- Using a string literal: if @OverloadedStrings@ is enabled, the 'WaveStyle'
  value can be represented using a color name or hex color string literal.
  See 'Data.Colour.Names.readColourName'.

Finally, there are a few special styles.

- 'WSError' is propagated throughout the signal hierarchy.
- 'WSDefault' is the only style to be replaced by the 'Clash.Shockwaves.Waveform.TStyled'
  translator, and gets turned into 'WSNormal'.
- 'WSInherit n' inherits the style of the _n_'th subsignal.
- 'WSVar' makes it possible to define style variables in config files - this can also
  be created by using a string literal starting with @$@, which uses 'WSDefault' as the
  fallback value.
- 'WSHidden' makes the signal appear as if it has not been assigned a value at all.
  This still allows the hidden text to be used in the construction of the value of
  a supersignal.

Some examples:

@
import Shockwaves.Style
import Shockwaves.Style.Colors as C

data Col = Red | Green | Blue | Yellow | Cyan | Magenta deriving ...

instance Waveform Col where
  styles = [ WSColor (RGB 255 0 0) -- RGB value
           , wsColor C.lime        -- Colour value
           , "blue"                -- color name
           , "#ffff00"             -- hexadecimal color
           , "$cyan"               -- style variable "cyan"; defaults to WSDefault
           , WSVar "magenta"       -- style variable "magenta", defaults to #ff00ff
                   "#f0f"
@

and in a translation:

@
Translation (Just ("x",Inherit 1,11))             -- appears as blue
  [ ("a",Translation (Just ("p","red" ,11)) [])   -- appears as red
  , ("b",Translation (Just ("q","blue",11)) []) ] -- appears as blue

Translation (Just ("x","blue",11))                   -- appears as WSError
  [ ("a",Translation (Just ("p",WSDefault,11)) [])   -- appears as WSNormal
  , ("b",Translation (Just ("q",WSError  ,11)) []) ] -- appears as WSError
@

-}

module Clash.Shockwaves.Style (
  WaveStyle(..),
  Color,
  RGB(..),
  wsColor,
  Word8,
) where
import Clash.Prelude
import Clash.Shockwaves.Internal.Types (WaveStyle(..),Color)
import Data.Colour.SRGB (RGB(..), toSRGB24)
import Data.Word (Word8)
import Data.Colour (Colour)

-- | Create a colored 'WaveStyle' from a color value defined in 'Double's.
--   This is the type of the predefined default colors in "Data.Colour".
wsColor :: Colour Double -> WaveStyle
wsColor = WSColor . toSRGB24
