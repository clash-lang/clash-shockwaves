{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fconstraint-solver-iterations=10 #-}

module Tests.Types where

import Clash.Prelude hiding (bitSize)
import Clash.Shockwaves.LUT
import Clash.Shockwaves.Waveform
import Data.Typeable

import qualified Data.List as L

{-

(void) / single constructor / multiple constructors
no fields / one field / two fields / multiple fields / struct

-}

data S = S
  deriving (ShowX, BitPack, NFDataX, Generic, Typeable, Waveform)
data M = Ma | Mb | Mc
  deriving (ShowX, BitPack, NFDataX, Generic, Typeable, Waveform)

data U = U
  deriving (ShowX, BitPack, NFDataX, Generic, Typeable, Waveform)
data F = M Bool Int
  deriving (ShowX, BitPack, NFDataX, Generic, Typeable, Waveform)

infixl 5 ://:
data Op a b = a ://: b
  deriving (ShowX, BitPack, NFDataX, Generic, Typeable)
instance (Waveform a, Waveform b) => Waveform (Op a b) where
  translator = renameFields [["lhs", "rhs"]] $ defaultTranslator @(Op a b)

data St = St {a :: Bool, b :: Int}
  deriving (ShowX, BitPack, NFDataX, Generic, Typeable, Waveform)

data C = Red | Green | Blue
  deriving (ShowX, BitPack, NFDataX, Generic, Typeable)
instance Waveform C where
  constructorStyles = [WSVar "red" "#f00", WSVar "green" "lime", WSVar "blue" "#0000ff"]

infixr 6 :**:
data Mix z
  = A
  | B Bool
  | C Bool Int
  | D {x :: Bool, y :: Int}
  | (Unsigned 4) :**: z
  deriving (ShowX, BitPack, NFDataX, Generic, Typeable, Waveform)

data L
  = La Bool Bool
  | Lb Bool Bool
  deriving (ShowX, BitPack, NFDataX, Generic, Typeable)
  deriving (Waveform) via (WaveformForLut L)

instance WaveformLUT L where
  translateL = translateWith (renderWith labelL styleL precL) splitL
   where
    labelL (La x y) = show x <> " <A> " <> show y
    labelL (Lb x y) = show x <> " <B> " <> show y

    styleL (La _ _) = "red"
    styleL (Lb _ _) = "green"

newtype Pointer a = Pointer (Unsigned a)
  deriving (Generic, BitPack, NFDataX, Typeable, ShowX)

instance (KnownNat a) => Waveform (Pointer a) where
  translator =
    Translator (bitSize @(Unsigned a))
      $ TAdvancedSum
        { index = (0, bitSize @(Unsigned a))
        , defTrans = Translator (bitSize @(Unsigned a)) $ TNumber NFHex (Just (2, "_")) "0X" False
        , rangeTrans = [((0, 1), tConst $ Just ("NULL", WSWarn, 11))]
        }

newtype NumRep a = NumRep a deriving (Generic, BitPack, NFDataX, Typeable, ShowX)

instance (Waveform a) => Waveform (NumRep a) where
  translator =
    Translator (bitSize @a)
      $ TAdvancedProduct
        { sliceTrans =
            L.map
              ((0, bitSize @a),)
              ( tRef @a
                  : L.map
                    (Translator (bitSize @a))
                    [ TNumber NFBin (Just (4, "_")) "0b" False
                    , TNumber NFOct (Just (4, "_")) "0o" False
                    , TNumber NFHex (Just (2, "_")) "0X" False
                    , TNumber NFUns (Just (3, "_")) "" False
                    , TNumber NFSig (Just (3, "_")) "" False
                    ]
              )
              <> [((bitSize @a - 1, bitSize @a), tRef @Bool)]
        , hierarchy =
            [("bin", 1), ("oct", 2), ("hex", 3), ("unsigned", 4), ("signed", 5), ("odd", 6)]
        , valueParts = [VPLit "{", VPRef 0 (-1), VPLit ", odd=", VPRef 6 (-1), VPLit "}"]
        , preco = 11
        }

newtype LittleEndian = LittleEndian (Unsigned 24)
  deriving (Generic, BitPack, Typeable, NFDataX, ShowX)

instance Waveform LittleEndian where
  translator =
    Translator 24
      $ TChangeBits
        { bits =
            BPConcat [BPLit "x1110", BPSlice (16, 24) BPIn, BPSlice (8, 16) BPIn, BPSlice (0, 8) BPIn]
        , sub = Translator 29 $ TNumber NFHex (Just (2, "_")) "0X" False
        }

data SumStruct = SSA {sub :: Maybe Bool} | SSB | SSC {sub2 :: Either Bool Bool} | SSD
  deriving (Generic, BitPack, Typeable, NFDataX, ShowX)

instance Waveform SumStruct where
  translator =
    Translator 4
      $ TSum
        [ Translator 2
            $ TProduct
              { start = "SSA "
              , sep = ""
              , stop = ""
              , preci = 10
              , preco = 10
              , labels = []
              , subs = [("sub", tRef @(Maybe Bool))]
              }
        , tDup "B" $ tConst $ Just ("SSB", WSDefault, 11)
        , Translator 2
            $ TProduct
              { start = "SSC "
              , sep = ""
              , stop = ""
              , preci = 10
              , preco = 10
              , labels = []
              , subs = [("sub", tRef @(Either Bool Bool))]
              }
        , tDup "D" $ tConst $ Just ("SSD", WSDefault, 11)
        ]
