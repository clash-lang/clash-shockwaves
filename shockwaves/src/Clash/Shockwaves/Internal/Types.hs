{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoFieldSelectors #-}

{- |
Copyright  :  (C) 2025-2026, QBayLogic B.V.
License    :  BSD2 (see the file LICENSE)
Maintainer :  QBayLogic B.V. <devops@qbaylogic.com>

Type definitions for Shockwaves.
-}
module Clash.Shockwaves.Internal.Types where

import Clash.Prelude hiding (sub)
import Clash.Shockwaves.Internal.BitList (BitList)
import Data.Data (Typeable)
import qualified Data.List as L
import Data.Map as M

import Control.DeepSeq (NFData (rnf))
import Data.Aeson hiding (Value)
import Data.Char (digitToInt)
import Data.Colour.Names (readColourName)
import Data.Colour.SRGB (Colour, RGB (..), toSRGB24)
import Data.Maybe (fromJust)
import Data.String (IsString)
import Data.Word (Word8)
import GHC.Exts (IsString (fromString))

-- some type aliases for clarity
type TypeName = String
-- ^ Name of a type.

type SubSignal = String
-- ^ Name of a subsignal.

type SignalName = SubSignal
-- ^ Name of a signal.

type Value = String
-- ^ Text displayed as the value of a signal.

type Prec = Integer
-- ^ Operator precedence of the value.

type Render = Maybe (Value, WaveStyle, Prec)
{- ^ Rendered value. This can be @Nothing@ is the value does not exists,
or a tuple of the text representation, style, and precedence.
-}

type LUTName = TypeName
-- ^ Reference to a LUT.

-- | Map that links signal names to their types.
type SignalMap = Map SignalName TypeName

-- | Map that links type names to their information.
type TypeMap = Map TypeName Translator

-- | Table of LUTs. Usually, the index is a type name, but this is not necessarily the case.
type LUTMap = Map LUTName LUT

-- | A lookup table of 't:Translation's.
type LUT = Map BitList Translation

-- | The color type used in 'WaveStyle'.
type Color = RGB Word8

{- | Translation of a value.
The translation consists of a 'Render' value (the representation of the value itself)
and a list of subsignal translations.
-}
data Translation
  = Translation Render [(SubSignal, Translation)]
  deriving (Show, Generic, ToJSON, NFData, Eq)

-- | The style in which a signal should be displayed.
data WaveStyle
  = {- | The default waveform style. It is rendered as 'WSNormal'.
    This is the only style overwritten by 'TStyled'.
    -}
    WSDefault
  | -- | An error value. Errors are propagated by translators.
    WSError
  | -- | Do not display any value, even if it exists.
    WSHidden
  | -- | Copy the style of the /n/th subsignal.
    WSInherit Natural
  | -- | A normal value.
    WSNormal
  | -- | A warning value.
    WSWarn
  | -- | An undefined value.
    WSUndef
  | -- | A high impedance value.
    WSHighImp
  | -- | A value that does not matter.
    WSDontCare
  | -- | A weakly defined value.
    WSWeak
  | -- | A custom color. See "Clash.Shockwaves.Style" for more information.
    WSColor Color
  | -- | A variable in a style configuration file, with a default.
    WSVar String WaveStyle
  deriving (Show, Generic, Eq)

instance NFData WaveStyle where
  rnf !_ = ()

-- | Different number formats.
data NumberFormat
  = -- | A signed decimal value.
    NFSig
  | -- | An unsigned decimal value.
    NFUns
  | -- | A hexadecimal value. Supports partially undefined values.
    NFHex
  | -- | An octal value. Supports partially undefined values.
    NFOct
  | -- | A binary value. Supports partially undefined values.
    NFBin
  deriving (Show, Typeable, Generic, NFData)

-- | A type for defining spacers and the way they are placed.
type NumberSpacer = Maybe (Integer, String)

-- | A structure value that shows what subsignals are present.
newtype Structure
  = Structure [(SubSignal, Structure)]
  deriving (Show, Generic, ToJSON)

{- | A translator. The translator has a width, indicating the number of bits it
translates, as well as a 'TranslatorVariant' that determines the translation algorithm.
-}
data Translator = Translator Int TranslatorVariant deriving (Show)

instance Show TypeRef where
  show _ = "*"

-- | A type-agnostic reference to various waveform details of a type.
data TypeRef = TypeRef
  { structureRef :: Structure
  -- ^ The structure of the translator.
  , translateBinRef :: BitList -> Translation
  {- ^ A function to translate binary data. Normally, this would be
  @translateBinT translatorRef@, but for 'TLut', the @translateL@ function
  in 'Clash.Shockwaves.LUT.WaveformLUT'.
  -}
  , translatorRef :: Translator
  -- ^ The translator used for the type.
  }

{- | The translation algorithm used.
Translator variants determine how the bits are interpreted, split, manipulated,
and in the end, translatated and displayed in the waveform viewer.
-}
data TranslatorVariant
  = {- | Use the translator of a different type. Note that the width value of the
    't:Translator's should match that of the target. The 't:TypeRef' parameter does not
    end up in the actual output, but is used to access functionality for the referenced
    type. Use @tRef@ to create this translator.
    -}
    TRef TypeName TypeRef
  | {- | A reference to a lookup table. Implement @Waveform@ through @WaveformLUT@
    to stably use this functionality.
    -}
    TLut LUTName TypeRef
  | {- | Select one translator to be used based on the first bits of the binary
    representation. Translate the rest of the bits using the selected translator.
    To be exact, if /k/ translators are provided, /ceil(log2(k))/ bits will be
    consumed to select the translator.

    No subsignals for the translators are created. Keep in mind that problems may
    occur if two translators specify subsignals with identical names.
    -}
    TSum [Translator]
  | {- | Use @index@ to take a slice of the binary data. This slice is interpreted
    as an unsigned integer. This index value is checked against the ranges in
    @rangeTrans@; the first translator with a value in the range is used.
    If no ranges match, the @defTrans@ is used.

    The selected translator is passed the full binary.

    **Important**: Slice indices start to the left, i.e. with the MSB!
    -}
    TAdvancedSum
      { index :: Slice
      -- ^ Slice of inputs to use
      , defTrans :: Translator
      -- ^ Default translator
      , rangeTrans :: [(ISlice, Translator)]
      -- ^ Ranges of indices (half-open) and their translators
      }
  | {- | Split the binary data into separate fields, translate each of these,
    and join together the values.
    Specifically, for each of the listed translators, consume as many bits as specified
    by the translator, then pass on the rest of the bits to the other translators.

    The value is constructed from the values of the subtranslators.
    A start, stop and separator string can be specified, as well as optional
    labels to put in front of the different values.

    Example:

    @
    data T = T{a::Bool,b::Bool}
    translatorVariantT = TProduct
    { subs = [("a",Bool,"b",Bool)],
    , start = "T{"
    , sep = ","
    , stop = "}"
    , labels = ["a=","b="]
    , preci = -1
    , preco = 11
    }
    @
    -}
    TProduct
      { subs :: [(SubSignal, Translator)]
      -- ^ List of fields to translate.
      , start :: Value
      -- ^ Text to insert at the start of the value.
      , sep :: Value
      -- ^ Text to use to separate values.
      , stop :: Value
      -- ^ Text to insert at the end of the value.
      , labels :: [Value]
      {- ^ List of labels to insert before each value.
      If empty, insert no labels.
      Else, the length must match that of @subs@.
      -}
      , preci :: Prec
      -- ^ Inner precedence: used on subvalues.
      , preco :: Prec
      -- ^ Outer precedence: used for the combined value.
      }
  | {- | An array value. This behaves much like 'TProduct', except that no labels
    can be provided, and all fields use the same translator. The fields are numbered
    starting from 0.
    -}
    TArray
      { sub :: Translator
      -- ^ Translator used for all values.
      , len :: Int
      -- ^ Length of the array.
      , start :: Value
      -- ^ Text inserted at the start of the value.
      , sep :: Value
      -- ^ Text to use to separate values.
      , stop :: Value
      -- ^ Text to insert at the end of the value.
      , preci :: Prec
      -- ^ Inner precedence: used on subvalues.
      , preco :: Prec
      -- ^ Outer precedence: used for the combined value.
      }
  | {- | Advance product type.
    First, a number of slices of the binary are translated.
    Then, the subsignals are picked from these translations,
    and the value is constructed from fixed strings and values from the translators.

    **Important**: Slice indices start to the left, i.e. with the MSB!
    -}
    TAdvancedProduct
      { sliceTrans :: [(Slice, Translator)]
      -- ^ A list of slices of the input, and translators to translate them with.
      , hierarchy :: [(SubSignal, Int)]
      -- ^ A list of subsignals, and what index of @sliceTrans@ to use for their values.
      , valueParts :: [ValuePart]
      -- ^ A list of value literals and references to the values in @sliceTrans@.
      , preco :: Prec
      -- ^ The precedence of the final value.
      }
  | {- | Translate the binary data using the translator specified, and duplicate
    the value into a subsignal of the provided name. This duplication applies
    the @WSInherit 0@ style to copy the actual style of the subvalue.
    -}
    TDuplicate SubSignal Translator
  | {- | Apply a style to a translation, replacing only 'WSDefault'.
    This translator is purely cosmetic and otherwise does not influence translation.
    -}
    TStyled WaveStyle Translator
  | {- | Modify the binary input of the contained translator
    The binary data is modified using @bits@ (see 'BitPart') before being passed
    onto the subtranslator.
    -}
    TChangeBits
      { sub :: Translator
      , bits :: BitPart
      }
  | {- | Translate the binary data as an integer. @format@ and @spacer@ determine
    how exactly the value is displayed.
    -}
    TNumber
      { format :: NumberFormat
      -- ^ Format used to display data.
      , spacer :: NumberSpacer
      -- ^ Optional spacer to improve readability.
      , prefix :: String
      -- ^ String to prefix the result with.
      , warn :: Bool
      -- ^ Whether to use WSWarn rather than WSError in case of undefined bits.
      }
  | -- | A constant translation value. The binary value provided is completely ignored.
    TConst Translation
  deriving (Show)

{- | Parts of the binary output of 'TChangeBits'.
Each constructor modifies bits in a certain way.

More may be added later.
-}
data BitPart
  = -- | Pass the binary data onto multiple 'BitPart's, and concatenate their results.
    BPConcat [BitPart]
  | -- | Return the 'BitList', ignoring the input.
    BPLit BitList
  | -- | Return a slice of the input. **Important**: slice indices start to the left, i.e. with the MSB!
    BPSlice Slice
  deriving (Show)

-- | Parts of the value of 'TAdvancedProduct'.
data ValuePart
  = -- | A literal string.
    VPLit String
  | -- | The value of a subtranslation parsed with outer precedence.
    VPRef Int Prec
  deriving (Show)

-- | A half open slice of 'Int's.
type Slice = (Int, Int)

-- | A half open slice of 'Integer's.
type ISlice = (Integer, Integer)

{- | A 'WaveStyle' may be constructed from a value in various ways.
Values starting with @$@ are treated as 'WSVar' with 'WSDefault' as fallback
value. Hexadecimals and color names are used to create 'WSColor' (see 'readColourName').
-}
instance IsString WaveStyle where
  fromString ('#' : hex) = WSColor $ go $ L.map (fromIntegral . digitToInt) hex
   where
    go :: [Word8] -> Color
    go [r, r', g, g', b, b'] = RGB (16 * r + r') (16 * g + g') (16 * b + b')
    go [r, g, b] = RGB (17 * r) (17 * g) (17 * b)
    go _ = error ("bad hex code #" <> hex)
  fromString ('$' : var) = WSVar var WSDefault
  fromString s =
    WSColor
      . toSRGB24
      . fromJust
      $ (readColourName s :: (Maybe (Colour Double)))

instance IsString ValuePart where
  fromString = VPLit

instance IsString BitPart where
  fromString s = BPLit $ fromString s

instance ToJSON BitPart where
  toJSON (BPConcat bp) = object ["C" .= bp]
  toJSON (BPLit bl) = object ["L" .= show bl]
  toJSON (BPSlice s) = object ["S" .= s]

instance ToJSON ValuePart where
  toJSON (VPLit s) = object ["L" .= s]
  toJSON (VPRef i p) = object ["R" .= [toJSON i, toJSON p]]

instance ToJSON Translator where
  toJSON (Translator w v) = object ["w" .= w, "v" .= v']
   where
    v' = case v of
      TRef n _ -> object ["R" .= n]
      TSum subs -> object ["S" .= toJSON subs]
      TAdvancedSum{index, defTrans, rangeTrans} ->
        object
          [ "S+"
              .= object
                [ "i" .= index
                , "d" .= defTrans
                , "t" .= rangeTrans
                ]
          ]
      TProduct{subs, start, sep, stop, labels, preci, preco} ->
        object
          [ "P"
              .= object
                [ "t" .= subs
                , "[" .= start
                , "," .= sep
                , "]" .= stop
                , "n" .= labels
                , "p" .= preci
                , "P" .= preco
                ]
          ]
      TConst t -> object ["C" .= toJSON t]
      TLut lut TypeRef{structureRef} -> object ["L" .= [toJSON lut, toJSON structureRef]]
      TNumber{format, spacer, prefix, warn} ->
        object
          [ "N"
              .= object
                [ "f" .= format
                , "s" .= spacer
                , "p" .= prefix
                , "w" .= warn
                ]
          ]
      TArray{sub, len, start, sep, stop, preci, preco} ->
        object
          [ "A"
              .= object
                [ "t" .= sub
                , "l" .= len
                , "[" .= start
                , "," .= sep
                , "]" .= stop
                , "p" .= preci
                , "P" .= preco
                ]
          ]
      TAdvancedProduct{sliceTrans, hierarchy, valueParts, preco} ->
        object
          [ "P+"
              .= object
                [ "t" .= sliceTrans
                , "h" .= hierarchy
                , "v" .= valueParts
                , "P" .= preco
                ]
          ]
      TStyled s t -> object ["X" .= [toJSON s, toJSON t]]
      TDuplicate n t -> object ["D" .= [toJSON n, toJSON t]]
      TChangeBits{sub, bits} ->
        object
          [ "B"
              .= object
                [ "t" .= sub
                , "b" .= bits
                ]
          ]

instance ToJSON WaveStyle where
  toJSON = \case
    WSDefault -> "D"
    WSError -> "E"
    WSHidden -> "H"
    WSInherit n -> object ["I" .= n]
    WSNormal -> "N"
    WSWarn -> "W"
    WSUndef -> "U"
    WSHighImp -> "Z"
    WSDontCare -> "X"
    WSWeak -> "Q"
    WSColor (RGB r g b) -> object ["C" .= [r, g, b, 255]]
    WSVar var dflt -> object ["V" .= [toJSON var, toJSON dflt]]
instance ToJSON NumberFormat where
  toJSON = \case
    NFSig -> "S"
    NFUns -> "U"
    NFHex -> "H"
    NFOct -> "O"
    NFBin -> "B"
