{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DerivingVia #-}

{-# OPTIONS_GHC -fconstraint-solver-iterations=10 #-}

module Tests.Types where

import Clash.Prelude
import Data.Typeable
import Clash.Shockwaves.Waveform
import Clash.Shockwaves.LUT

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
  deriving (ShowX, BitPack, NFDataX, Generic, Typeable, Waveform)
data St = St{a::Bool,b::Int}
  deriving (ShowX, BitPack, NFDataX, Generic, Typeable, Waveform)

data C = Red | Green | Blue
   deriving (ShowX, BitPack, NFDataX, Generic, Typeable)
instance Waveform C where
  styles = [WSVar "red" "#f00",WSVar "green" "lime",WSVar "blue" "#0000ff"]

infixr 6 :**:
data Mix z
  = A
  | B Bool
  | C Bool Int
  | D {x::Bool,y::Int}
  | (Unsigned 4) :**: z
  deriving (ShowX, BitPack, NFDataX, Generic, Typeable, Waveform)

data L
  = La Bool Bool
  | Lb Bool Bool
  deriving (ShowX,BitPack, NFDataX, Generic, Typeable)
  deriving Waveform via (WaveformForLUT L)

instance WaveformLUT L where
  translateL = translateWith (renderWith labelL styleL precL) splitL
    where
      labelL (La x y) = show x <> " <A> " <> show y
      labelL (Lb x y) = show x <> " <B> " <> show y

      styleL (La _ _) = "red"
      styleL (Lb _ _) = "green"


newtype Pointer a = Pointer (Unsigned a) deriving (Generic,BitPack,NFDataX,Typeable,ShowX)

instance KnownNat a => Waveform (Pointer a) where
  translator = Translator (width @(Unsigned a)) $ TAdvancedSum
    { index = (0,width @(Unsigned a))
    , defTrans = Translator (width @(Unsigned a)) $ TNumber NFHex (Just (2,"_"))
    , rangeTrans = [((0,1),tConst $ Just ("NULL",WSWarn,11))]
    }

newtype NumRep a = NumRep a deriving (Generic,BitPack,NFDataX,Typeable,ShowX)

instance Waveform a => Waveform (NumRep a) where
  translator = Translator (width @a) $ TAdvancedProduct
    { sliceTrans =
      L.map ((0,width @a),)
        ( tRef (Proxy @a) :
          L.map (Translator (width @a))
            [ TNumber NFBin (Just (4,"_"))
            , TNumber NFOct (Just (4,"_"))
            , TNumber NFHex (Just (2,"_"))
            , TNumber NFUns (Just (3,"_"))
            , TNumber NFSig (Just (3,"_"))
            ])
      <> [((width @a-1,width @a),tRef $ Proxy @Bool)]
    , hierarchy = [("bin",1),("oct",2),("hex",3),("unsigned",4),("signed",5),("odd",6)]
    , valueParts = [VPLit "{",VPRef 0 (-1),VPLit ", odd=",VPRef 6 (-1), VPLit "}"]
    , preco = 11
    }

newtype LittleEndian = LittleEndian (Unsigned 24)
  deriving (Generic,BitPack,Typeable,NFDataX,ShowX)

instance Waveform LittleEndian where
  translator = Translator 24 $ TChangeBits
    { bits = BPConcat [BPLit "x1110",BPSlice (16,24), BPSlice (8,16),BPSlice (0,8)]
    , sub = Translator 29 $ TNumber NFHex (Just (2,"_"))
    }