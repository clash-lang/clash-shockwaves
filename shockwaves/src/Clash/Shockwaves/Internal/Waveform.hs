{-|
Copyright  :  (C) 2025-2026, QBayLogic B.V.
License    :  BSD2 (see the file LICENSE)
Maintainer :  QBayLogic B.V. <devops@qbaylogic.com>

The 'Waveform' class, functions derived from it, special 'Waveform' variants such as
'WaveformLUT', and 'Waveform' instances for default types.
-}

{-# LANGUAGE CPP #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

{-# OPTIONS_GHC -fconstraint-solver-iterations=10 #-}

module Clash.Shockwaves.Internal.Waveform where

import           Clash.Prelude

import           Clash.Shockwaves.Internal.Types
import qualified Clash.Shockwaves.BitList as BL
import           Clash.Shockwaves.BitList (BitList)
import           Clash.Shockwaves.Internal.Translator
import           Clash.Shockwaves.Internal.Util
import           Clash.Shockwaves.Internal.TH.Waveform (deriveWaveformTuples)

import           GHC.Generics
import           Data.Proxy
import           Data.Typeable
import qualified Data.List            as L
import           Data.Maybe           (fromMaybe,listToMaybe)
import           Data.Char            (isAlpha)

-- for standard type instances
import           Data.Int             (Int8,Int16,Int32,Int64)
import           Data.Word            (Word8,Word16,Word32,Word64)

import           Clash.Num.Zeroing    (Zeroing)
import           Clash.Num.Wrapping   (Wrapping)
import           Clash.Num.Saturating (Saturating)
import           Clash.Num.Overflowing(Overflowing)
import           Clash.Num.Erroring   (Erroring)
import           Data.Complex         (Complex)
import           Data.Ord             (Down)
import           Data.Functor.Identity(Identity)


{- FOURMOLU_DISABLE -}
#ifndef MAX_TUPLE_SIZE
#ifdef LARGE_TUPLES

#if MIN_VERSION_ghc(9,0,0)
import GHC.Settings.Constants (mAX_TUPLE_SIZE)
#else
import Constants (mAX_TUPLE_SIZE)
#endif
#define MAX_TUPLE_SIZE (fromIntegral mAX_TUPLE_SIZE)

#else
#ifdef HADDOCK_ONLY
#define MAX_TUPLE_SIZE 3
#else
#define MAX_TUPLE_SIZE 12
#endif
#endif
#endif
{- FOURMOLU_ENABLE -}

-- making values

-- | Get a 'Render' from a 'Value' using 'WSDefault' and precedence 11.
rFromVal :: Value -> Render
rFromVal v = Just (v,WSDefault,11)

-- | Get a 't:Translation' from a 'Value' using 'WSDefault' and precedence 11.
tFromVal :: Value -> Translation
tFromVal v = Translation (rFromVal v) []

-- | Create an error value from an optional error message.
errMsg :: Maybe Value -> Value
errMsg = maybe "undefined" (\e -> "{undefined: "<>e<>"}")


-- | First 'WaveStyle' in an infinite list of values.
styHead :: [WaveStyle] -> WaveStyle
styHead (s:_) = s
styHead _ = error "style list must be long enough"



-- making translators

-- | Wrap a 't:Translator' in a 'TStyled' translator using some style, unless the
-- provided style is 'WSDefault'.
wrapStyle :: WaveStyle -> Translator -> Translator
wrapStyle WSDefault t = t
wrapStyle s         t = tStyled s t


-- | Wrap a 't:Translator' in a 'TStyled' variant translator with the
-- provided style.
tStyled :: WaveStyle -> Translator -> Translator
tStyled s (Translator w v) = Translator w $ TStyled s (Translator w v)

-- | Wrap a 't:Translator' in a 'TDuplicate' variant translator with the
-- provided subsignal name.
tDup :: SubSignal -> Translator -> Translator
tDup name (Translator w t) = Translator w $ TDuplicate name (Translator w t)

-- | Generate a translator reference for a type.
tRef :: Waveform a => Proxy a -> Translator
tRef (_::Proxy a) = Translator (width @a) $ TRef (typeName @a) TypeRef
  { translateBinRef = translateBin @a
  , translatorRef = translator @a
  , structureRef = structure @a
  }

-- | Create a constant translator that consumes 0 bits and has no subsignals.
tConst :: Render -> Translator
tConst r = Translator 0 $ TConst $ Translation r []

-- | Create a LUT translator for a type, using the translation function of 'WaveformLUT'.
tLut :: forall a. (Waveform a, WaveformLUT a) => Proxy a -> Translator
tLut _ = Translator (width @a)
  $ TLut (typeName @a) TypeRef
      { translateBinRef = translateL @a . BL.binUnpack
      , structureRef = structureL @a
      , translatorRef = translator @a
      }



------------------------------------------ WAVEFORM --------------------------------------

{-|

'Waveform' is the main class for making types displayable in the waveform viewer.
The class is responsible for defining an appropriate translator and subsignal
structure, as well as registering types.

To make a LUT approache possible, the class must also be able to translate values,
and to register individual values.

By default, 'GHC.Generics.Generic' is used to automatically derive this behaviour.
Extra classes are provided to help implement lookup tables or common types,
like numerical translators. Custom implementations are also very possible.


-}

class (Typeable a, BitPack a) => Waveform a where
  -- | Provide the type name.
  -- Overriding this value is only really useful for derive via strategies.
  typeName :: TypeName
  typeName = typeNameP (Proxy @a)

  -- | The translator used for the data type. Must match the structure value.
  translator :: Translator
  default translator :: (WaveformG (Rep a ())) => Translator
  translator = translatorG @(Rep a ()) (width @a) (styles' @a)

  -- | List of styles used for constructors.
  --
  -- Since assigning different constructors different colors is a very common usecase
  -- of the waveform style,
  -- this list can be overridden to provides styles for the constructors, in order.
  -- To not change a style, use 'WSDefault'.
  styles :: [WaveStyle]
  styles = []

  -- | Runtime bitsize of the type.
  width :: Int
  width = bitsize (Proxy @a)

-- | Function to translate values. This function creates a translation from
-- the binary representation of the data using translateBin, and the translator.
translate :: forall a. (Waveform a, BitPack a) => a -> Translation
translate = translateBin @a . BL.binPack

-- | Translate binary data.
-- Normally, this simply translates the value according to the translator.
-- For LUTs, this involves translating the value back to the original type and
-- translating it using a specially defined translation function.
translateBin :: forall a. Waveform a => BitList -> Translation
translateBin = translateBinT (translator @a)

-- | Register this type and all its subtypes.
addTypes :: forall a. Waveform a => TypeMap -> TypeMap
addTypes = addTypesT $ tRef (Proxy @a)

-- | Helper function that fills the 'styles' list with 'WSDefault'.
styles' :: forall a. Waveform a => [WaveStyle]
styles' = styles @a <> L.repeat WSDefault

-- | Check if the type requires LUTs for translation.
hasLut :: forall a. Waveform a => Bool
hasLut = hasLutT $ translator @a

-- | Return the structure of a type.
structure :: forall a. Waveform a => Structure
structure = structureT $ translator @a

-- | Add all (sub) values that use 'TLut' to their respective LUTs.
addValue :: forall a. Waveform a => a -> [LUTMap -> LUTMap]
addValue = addValueT (translator @a) . BL.binPack

------------------------------------------- GENERIC -------------------------------------

-- | A class for obtaining the required behaviour of 'Waveform' through "GHC.Generics".
-- The exact details might change later; use at your own risk.
class WaveformG a where
  -- | Given a bitsize and list of styles for the constructors, provide a translator.
  -- 
  -- Defined only for full types and constructors
  translatorG :: Int -> [WaveStyle] -> Translator

  -- | Return a list of translators for constructors as subsignals.
  --
  -- Defined for constructors, @:+:@ and types with multiple constructors.
  constrTranslatorsG :: [WaveStyle] -> [Translator]

  -- | Return a list of translators for fields.
  --
  -- Defined for fields, @:*:@, constructors, and types with a single constructor.
  -- Product type subsignals are labeled (numbered) for types and constructors only.
  fieldTranslatorsG :: [(SubSignal,Translator)]

  -- | Bitsize of a type. Only used to determine the width of constructors
  -- (and their fields).
  --
  -- Defined for constructors, @:*:@, and fields.
  widthG :: Int -- for individual constructors

  -- | For LUTs.
  -- Create translation subsignals from supplied 'Render' value.
  -- Duplicate the value if there are multiple constructors, and just translate the fields.
  -- If getting the constructor fails, create no subsignals.
  --
  -- Defined for types, @:+:@ and constructors.
  translateWithG :: Render -> a -> [(SubSignal,Translation)]

  -- | For LUTs.
  -- Translate all fields of a (the) constructor.
  --
  -- Defined for constructors, @:*:@, fields and types with 1 constructor.
  translateFieldsG :: a -> [(SubSignal,Translation)]



-- void type (assuming it has a custom bitpack implementation)
instance WaveformG (D1 m1 V1 k) where
  translatorG _ _ = tConst Nothing
  constrTranslatorsG _ = undefined
  fieldTranslatorsG = undefined

  widthG = undefined

  translateWithG _ _ = []
  translateFieldsG = undefined

-- single constructor type
instance (WaveformG (C1 m2 s k), WaveformG (s k)) => WaveformG (D1 m1 (C1 m2 s) k) where
  translatorG = translatorG @(C1 m2 s k)
  constrTranslatorsG = undefined
  fieldTranslatorsG = fieldTranslatorsG @(C1 m2 s k)

  widthG = undefined

  translateWithG r x = case translateWithG r (unM1 x) of
    [(_,Translation _ subs)] -> subs --remove duplicated singal from constructor
    _                        -> undefined
  translateFieldsG x = translateFieldsG (unM1 x)


-- multiple constructors type
instance WaveformG ((a :+: b) k) => WaveformG (D1 m1 (a :+: b) k) where
  translatorG w sty = Translator w . TSum $ constrTranslatorsG @((a :+: b) k) sty
  constrTranslatorsG = constrTranslatorsG @((a :+: b) k)
  fieldTranslatorsG = undefined

  widthG = undefined

  translateWithG r x = fromMaybe [] $ safeWHNF $ translateWithG r (unM1 x)
  translateFieldsG = undefined


-- multiple constructors
instance (WaveformG (a k), WaveformG (b k)) => WaveformG ((a :+: b) k) where
  translatorG = undefined
  constrTranslatorsG sty = a <> b
    where
      a = constrTranslatorsG @(a k) sty
      b = constrTranslatorsG @(b k) (L.drop (L.length a) sty)
  fieldTranslatorsG = undefined

  widthG = undefined

  translateWithG r xy = case safeWHNF xy of
    Just (L1 x) -> translateWithG r x
    Just (R1 y) -> translateWithG r y
    Nothing     -> []
  translateFieldsG = undefined

-- struct constructor
instance (WaveformG (fields k), KnownSymbol name)
  => WaveformG (C1 (MetaCons name fix True) fields k) where
  translatorG _ sty = t'
    where
      t' = case styHead sty of
        WSDefault ->
          if L.length subs == 1 then
            tStyled (WSInherit 0) t
          else t
        s -> tStyled s t
      subs = fieldTranslatorsG @(C1 (MetaCons name fix True) fields k)
      t = Translator (widthG @(fields k)) $ TProduct
        { start  = sym @name <> "{"
        , sep    = ", "
        , stop   = "}"
        , preci  = -1
        , preco  = 11
        , labels = L.map ((<>" = ") . fst) subs
        , subs   = subs
        }

  constrTranslatorsG sty =
    [ tDup (sym @name)
      $ translatorG @(C1 (MetaCons name fix True) fields k) undefined sty ]
  fieldTranslatorsG = fieldTranslatorsG @(fields k)

  widthG = undefined

  translateWithG r x = [(sym @name, Translation r $ translateFieldsG x)]
  translateFieldsG x = translateFieldsG (unM1 x)

-- applicative product
instance (WaveformG (fields k), KnownSymbol name, PrecF fix)
  => WaveformG (C1 (MetaCons name fix False) fields k) where
  translatorG _ sty = t'
    where
      t' = case styHead sty of
        WSDefault ->
          if L.length subs == 1 then
            tStyled (WSInherit 0) t
          else t
        s -> tStyled s t
      subs = fieldTranslatorsG @(C1 (MetaCons name fix False) fields k)
      t = if isOperator then
            Translator (widthG @(fields k)) $ TProduct
              { start  = ""
              , sep    = " " <> sym @name <> " "
              , stop   = ""
              , preci  = precF @fix
              , preco  = precF @fix
              , labels = []
              , subs = subs
              }
          else
            Translator (widthG @(fields k)) $ TProduct
              { start  = case subs of
                          [] -> sname
                          _  -> sname <> " "
              , sep    = " "
              , stop   = ""
              , preci  = 10
              , preco  = case subs of
                          [] -> 11
                          _  -> 10
              , labels = []
              , subs = subs
              }

      sname = safeName (sym @name)
      isOperator = not (isAlpha $ fromMaybe '_' $ listToMaybe $ sym @name) && (L.length subs == 2)

  constrTranslatorsG sty =
    [ tDup (sym @name)
      $ translatorG @(C1 (MetaCons name fix False) fields k) undefined sty ]
  fieldTranslatorsG = enumLabel $ fieldTranslatorsG @(fields k)

  widthG = undefined

  translateWithG r x = [(sym @name, Translation r $ translateFieldsG x)]
  translateFieldsG x = enumLabel $ translateFieldsG (unM1 x)



-- no fields
instance WaveformG (U1 k) where
  translatorG = undefined
  constrTranslatorsG = undefined
  fieldTranslatorsG = []

  widthG = 0

  translateWithG _ _ = undefined
  translateFieldsG _ = []


-- | Lazily get left field.
left :: (a :*: b) k -> a k
left (x :*: _y) = x

-- | Lazily get right field.
right :: (a :*: b) k -> b k
right (_x :*: y) = y

-- multiple fields
instance (WaveformG (a k), WaveformG (b k)) => WaveformG ((a :*: b) k) where
  translatorG = undefined
  constrTranslatorsG = undefined
  fieldTranslatorsG = fieldTranslatorsG @(a k) <> fieldTranslatorsG @(b k)

  widthG = widthG @(a k) + widthG @(b k)

  translateWithG _ _ = undefined
  translateFieldsG xy = translateFieldsG (left xy) <> translateFieldsG (right xy)

-- struct field
instance (Waveform t, KnownSymbol name)
  => WaveformG (S1 (MetaSel (Just name) p q r) (Rec0 t) k) where
  translatorG = undefined
  constrTranslatorsG = undefined
  fieldTranslatorsG = [(sym @name, tRef (Proxy @t))]

  widthG = width @t

  translateWithG _ _ = undefined
  translateFieldsG x = [(sym @name,translate $ unK1 $ unM1 x)]


-- unnamed field
instance (Waveform t) => WaveformG (S1 (MetaSel Nothing p q r) (Rec0 t) k) where
  translatorG = undefined
  constrTranslatorsG = undefined
  fieldTranslatorsG = [("", tRef (Proxy @t))]

  widthG = width @t

  translateWithG _ _ = undefined
  translateFieldsG x = [("",translate $ unK1 $ unM1 x)]










------------------------------------------------ LUTS ------------------------------------

{-|
Class for easily defining custom translations for a type by using LUTs.
To use this class, a type must derive 'Waveform' via 'WaveformForLUT'.

Bye default, the implementation uses 'GHC.Generics.Generic' for defining subsignals
and operator precedence, and 'Show' for displaying the value.
-}
class (Typeable a, BitPack a) => WaveformLUT a where
  -- | Provides the hierarchy of subsignals.
  structureL :: Structure
  default structureL :: (WaveformG (Rep a ())) => Structure
  structureL = structureT $ translatorG @(Rep a ()) 0 (L.repeat WSDefault)

  -- | Translate a value. The translations must adhere to the structure defined in 'structureL'.
  -- This function must be robust to @undefined@ values!
  translateL :: a -> Translation
  default translateL :: (Generic a, Show a, WaveformG (Rep a ()), PrecG (Rep a ())) => a -> Translation
  translateL = translateWith renderShow splitL

-- | Make sure a 't:Translation' is fully defined. If not, return a 't:Translation' with @"undefined"@.
safeTranslation :: Translation -> Translation
safeTranslation = safeValOr (errorT "undefined")

-- | Given a function that renders a value, and a function that (given this 'Render')
-- prodices the subsignals, create a translation.
-- If rendering fails, @"unknown"@ is displayed. If creating the subsignals fails, no subsignals are shown.
translateWith :: (a -> Render) -> (Render -> a -> [(SubSignal,Translation)]) -> a -> Translation
translateWith d s x = Translation ren subs
  where
    ren = safeValOr (errorR "undefined") $ d x
    subs = safeValOr [] $
            s ren x

-- | Display a value with 'Show', the default wave style, and operator precedence determined using 'Generic'.
renderShow :: (Show a, Generic a, PrecG (Rep a ())) => a -> Render
renderShow = renderWith show (const WSDefault) precL

-- | Display a value with the provided functions for creating the text value, style and operator precedence.
renderWith :: (a -> Value) -> (a -> WaveStyle) -> (a -> Prec) -> a -> Render
renderWith v s p x = Just (v x, s x, p x)

-- | Display an atomic value (such as a number) using the provided function to obtain the value.
-- (normal wavestyle, precedence 11).
translateAtomWith :: (a -> Value) -> a -> Translation
translateAtomWith f = translateWith (renderWith f (const WSDefault) (const 11)) noSplit

-- | Display an atomic value (like a number) with 'Show'. See 'translateAtomWith'.
translateAtomShow :: (Show a) => a -> Translation
translateAtomShow = translateAtomWith show

-- | Render an atomic value representing a signed number.
-- If the render value is found to start with @-@, the precedence is set to 0.
translateAtomSigWith :: (Show a) => (a -> Value) -> a -> Translation
translateAtomSigWith f = translateWith go noSplit
  where
    go x = Just (v,WSDefault,p)
      where
        v = f x
        p = case v of
          '-':_ -> 0
          _     -> 11 

-- | Render an atomic value representing a signed number using 'show'.
-- See 'translateAtomSigWith'.
translateAtomSigShow :: (Show a) => a -> Translation
translateAtomSigShow = translateAtomSigWith show


-- | Create subsignals for the constructors and fields.
-- Constructor translations are a copy of the toplevel render value provided.
splitL :: (Generic a, WaveformG (Rep a ())) => Render -> a -> [(SubSignal, Translation)]
splitL r x = translateWithG r (from @_ @() x)

-- | Create no subsignals for this type.
noSplit :: Render -> a -> [(SubSignal,Translation)]
noSplit _r _x = []

-- | Get the operator precedence of a value.
precL :: (PrecG (Rep a ()), Generic a) => a -> Prec
precL x = precG (from @_ @() x)

-- | Type for deriving 'Waveform' for types implementing 'WaveformLUT'.
--
-- @
-- type T = ... deriving (...)
-- deriving via WaveformForLUT T instance Waveform T
--
-- isntance WaveformLUT T where
--   ...
-- @
newtype WaveformForLUT a = WfLUT a deriving (Generic,BitPack,Typeable)

instance (Waveform a, WaveformLUT a, BitPack a, Typeable a)
  => Waveform (WaveformForLUT a) where
  typeName = typeNameP (Proxy @a)

  translator = tLut (Proxy @a)






----------------------------------------------- PREC ----------------------------------

-- Stuff for figuring out the operator precedence of a type.

-- | Helper class for determining the precedence and number of fields of a
-- value's constructor.
class (Generic a) => PrecG a where
  -- | Operator precedence of a value.
  precG :: a -> Prec

  -- | Return the number of fields of a constructor.
  -- This is needed to determine whether a constructor is atomic or not.
  nFields :: Integer
  nFields = undefined

-- get constructor(s)
instance PrecG (c k) => PrecG (D1 m1 c k) where
  precG M1{unM1=x} = precG x

-- no constructors (void tpye)
instance PrecG (V1 k) where
  precG _ = 11

-- multiple constructors
instance (PrecG (a k), PrecG (b k)) => PrecG ((a :+: b) k) where
  precG (L1 x) = precG x
  precG (R1 y) = precG y

-- struct
instance (PrecG (fields k), PrecF fix)
  => PrecG (C1 (MetaCons name fix True) fields k) where
  precG _ = 11

-- applicative
instance (PrecG (fields k), PrecF fix)
  => PrecG (C1 (MetaCons name fix False) fields k) where
  precG _ = if nFields @(fields k) == 0 then 11 else precF @fix


-- count fields
instance PrecG (U1 k) where
  precG = undefined
  nFields = 0

instance (PrecG (a k), PrecG (b k)) => PrecG ((a :*: b) k) where
  precG = undefined
  nFields = nFields @(a k) + nFields @(b k)

instance PrecG (S1 (MetaSel n p q r) t k) where
  precG = undefined
  nFields = 1


-- | Class for obtaining the runtime precedence of a typelevel fixity value.
class PrecF (f::FixityI) where
  -- | Return the precedence of a fixity value as an 'Integer'.
  precF :: Prec
instance PrecF PrefixI where
  precF = 10
instance (KnownNat p) => PrecF (InfixI a p) where
  precF = natVal (Proxy @p)









---------------------------------------- OTHER VARIANTS ----------------------------------

-- CONST

-- | Helper class for defining a constant translation value. To use this,
-- derive Waveform via WaveformForConst.
class (BitPack a, Typeable a) => WaveformConst a where
  -- | The constant translation value. Overwrite this if the translation has subsignals.
  constTrans :: Translation
  constTrans = Translation (constRen @a) []
  -- | Constant render value. Overwrite this if the constant value has no subsignals.
  constRen :: Render
  constRen = undefined
  {-# MINIMAL constTrans | constRen #-}

-- | Helper class for deriving 'Waveform' for types implementing 'WaveformConst'.
newtype WaveformForConst a = WfConst a deriving (Generic,BitPack,Typeable)

instance (WaveformConst a, BitPack a, Typeable a)
  => Waveform (WaveformForConst a) where
  typeName = typeNameP (Proxy @a)
  translator = Translator (bitsize $ Proxy @a) $ TConst $ constTrans @a




-- NUMBERS

-- | Helper class for deriving 'Waveform' for numerical types.
-- Options are provided at the type level (signed, format).
--
-- Example:
-- @
-- deriving via WaveformForNumber NFSig ('Just '(3,"_")) instance Waveform (Signed 3)
-- @
newtype WaveformForNumber (f::NumberFormat) (s::Maybe NSPair) a
  = WfNum a
  deriving (Generic,BitPack,Typeable)

-- | Pair of a 'Nat' and 'Symbol', used for type-level spacer values.
type NSPair = (Nat,Symbol)

instance (
    BitPack a
  , Typeable a
  , Typeable f
  , Typeable s
  , KnownNFormat f
  , KnownNSpacer s
  ) => Waveform (WaveformForNumber (f::NumberFormat) (s::Maybe NSPair) a) where
  typeName = typeNameP (Proxy @a)
  translator =
      Translator (width @(WaveformForNumber f s a))
    $ TNumber{format = formatVal (Proxy @f), spacer = spacerVal (Proxy @s)}

-- | Default spacer for decimal values (@_@ every 3 digits)
type DecSpacer = 'Just '(3,"_")
-- | Default spacer for hexadecimal values (@_@ every 2 digits) 
type HexSpacer = 'Just '(2,"_")
-- | Default spacer for octal values (@_@ every 4 digits)
type OctSpacer = 'Just '(4,"_")
-- | Default spacer for binary values (@_@ every 8 digits)
type BinSpacer = 'Just '(8,"_")
-- | Add @_@ every /n/ digits.
type SpacerEvery n = 'Just '(n,"_")
-- | Do not add spacers.
type NoSpacer = 'Nothing :: (Maybe NSPair)


-- | Class for turning a type level 'NumberFormat' into a runtime value.
class KnownNFormat (f::NumberFormat) where
  formatVal :: forall proxy. proxy f -> NumberFormat
instance KnownNFormat NFSig where
  formatVal _ = NFSig
instance KnownNFormat NFUns where
  formatVal _ = NFUns
instance KnownNFormat NFHex where
  formatVal _ = NFHex
instance KnownNFormat NFOct where
  formatVal _ = NFOct
instance KnownNFormat NFBin where
  formatVal _ = NFBin

-- | Type to get the runtime value of a type-level number spacer.
class KnownNSpacer (f :: Maybe NSPair) where
  spacerVal :: proxy f -> Maybe (Integer, String)
instance KnownNSpacer 'Nothing where
  spacerVal _ = Nothing
instance (KnownNat n, KnownSymbol s) => KnownNSpacer ('Just '(n, s)) where
  spacerVal _ = Just (natVal (Proxy @n), sym @s)












--------------------------------------- IMPLEMENTATIONS ----------------------------------

instance WaveformConst () where
  constRen = rFromVal "()"
deriving via WaveformForConst () instance Waveform ()

-- | Configure styles through style variables @bool_false@ and @bool_true@.
instance Waveform Bool where
  translator = Translator 1 $ TSum
    [ tConst $ Just ("False","$bool_false",11)
    , tConst $ Just ("True" ,"$bool_true" ,11) ]

-- | Configure styles through style variables @maybe_nothing@ and @maybe_just@.
instance (Waveform a) => Waveform (Maybe a) where
  translator = Translator (width @(Maybe a)) $ TSum
    [ Translator 0 $ TConst $ Translation (Just ("Nothing","$maybe_nothing",11)) []
    , tStyled (WSVar "$maybe_just" (WSInherit 0)) $ Translator (width @a) $ TProduct
      { start = "Just "
      , sep = ""
      , stop = ""
      , labels = []
      , preci = 10
      , preco = 10
      , subs = [("Just.0",tRef (Proxy @a))]
      }
    ]


-- | Configure styles through style variables @either_left@ and @either_right@.
instance (Waveform a, Waveform b) => Waveform (Either a b) where
  styles = ["$either_left","$either_right"]

instance (BitPack Char) => WaveformLUT Char where
  structureL = Structure []
  translateL = translateAtomShow
deriving via WaveformForLUT Char instance (BitPack Char) => Waveform Char

instance WaveformLUT Bit where
  structureL = Structure []
  translateL = translateAtomShow
deriving via WaveformForLUT Bit instance Waveform Bit

instance WaveformLUT Double where
  structureL = Structure []
  translateL = translateAtomSigShow
deriving via WaveformForLUT Double instance Waveform Double

instance WaveformLUT Float where
  structureL = Structure []
  translateL = translateAtomSigShow
deriving via WaveformForLUT Float instance Waveform Float

deriving via WaveformForNumber NFSig DecSpacer Int instance Waveform Int
deriving via WaveformForNumber NFSig DecSpacer Int8 instance Waveform Int8
deriving via WaveformForNumber NFSig DecSpacer Int16 instance Waveform Int16
deriving via WaveformForNumber NFSig DecSpacer Int32 instance Waveform Int32
deriving via WaveformForNumber NFSig DecSpacer Int64 instance Waveform Int64

instance Waveform Ordering

deriving via WaveformForNumber NFUns DecSpacer Word instance Waveform Word
deriving via WaveformForNumber NFUns DecSpacer Word8 instance Waveform Word8
deriving via WaveformForNumber NFUns DecSpacer Word16 instance Waveform Word16
deriving via WaveformForNumber NFUns DecSpacer Word32 instance Waveform Word32
deriving via WaveformForNumber NFUns DecSpacer Word64 instance Waveform Word64

deriving via WaveformForNumber NFSig DecSpacer (Signed n)
  instance (KnownNat n) => Waveform (Signed n)
deriving via WaveformForNumber NFUns DecSpacer (Unsigned n)
  instance (KnownNat n) =>  Waveform (Unsigned n)
deriving via WaveformForNumber NFUns DecSpacer (Index n)
  instance (1 <= n, KnownNat n) => Waveform (Index n)

instance Waveform a => Waveform (Complex a)

instance Waveform a => Waveform (Down a)

instance Waveform a => Waveform (Identity a)



-- number wrappers
instance (Waveform a) => Waveform (Zeroing a) where
  translator = tDup "zeroing" $ tRef (Proxy @a)

instance (Waveform a) => Waveform (Wrapping a) where
  translator = tDup "wrapping" $ tRef (Proxy @a)

instance (Waveform a) => Waveform (Saturating a) where
  translator = tDup "saturating" $ tRef (Proxy @a)

instance (Waveform a) => Waveform (Overflowing a) where
  translator = tDup "overflowing" $ tRef (Proxy @a)

instance (Waveform a) => Waveform (Erroring a) where
  translator = tDup "erroring" $ tRef (Proxy @a)


-- vectors
instance (KnownNat n, Waveform a) => Waveform (Vec n a) where
  translator = Translator (width @(Vec n a)) $ if natVal (Proxy @n) /= 0 then
    TArray
      { start = ""
      , sep = " :> "
      , stop = " :> Nil"
      , preci = 5
      , preco = 5
      , len = fromIntegral $ natVal (Proxy @n)
      , sub = tRef (Proxy @a)
      }
    else
      TConst $ tFromVal "Nil"


deriving via WaveformForNumber NFBin BinSpacer (BitVector n)
  instance (KnownNat n) => Waveform (BitVector n)

-- fixed point
instance (BitPack (Fixed r i f), KnownNat i, KnownNat f, Show (Fixed r i f), Typeable r)
  => WaveformLUT (Fixed r i f) where
  structureL = Structure []
  translateL = translateAtomSigShow
deriving via WaveformForLUT (Fixed r i f)
  instance (BitPack (Fixed r i f), KnownNat i, KnownNat f, Show (Fixed r i f), Typeable r)
    => Waveform (Fixed r i f)

-- snat
instance (KnownNat n, BitPack (SNat n)) => WaveformConst (SNat n) where
  constRen = rFromVal $ show $ natVal $ Proxy @n
deriving via WaveformForConst (SNat n)
  instance (KnownNat n, BitPack (SNat n)) => Waveform (SNat n)


-- RTree implementation

-- | Helper family for implementing 'Waveform' for 'RTree'.
type family RTreeIsLeaf d where
  RTreeIsLeaf 0 = True
  RTreeIsLeaf d = False

instance (Waveform a, KnownNat d, WaveformRTree (RTreeIsLeaf d) d a)
  => Waveform (RTree d a) where
  translator = translatorRTree @(RTreeIsLeaf d) @d @a

-- | Helper class for implementing 'Waveform' for 'RTree'.
class WaveformRTree (isLeaf::Bool) d a where
  translatorRTree :: Translator

instance (Waveform a) => WaveformRTree True 0 a where
  translatorRTree = tRef (Proxy @a)

instance (Waveform (RTree d1 a), Waveform a, d ~ d1 + 1, KnownNat d, KnownNat d1)
  => WaveformRTree False d a where
  translatorRTree = Translator (bitsize $ Proxy @(RTree d a)) $ TProduct
      { start = "<"
      , sep = ","
      , stop = ">"
      , labels = []
      , preci = -1
      , preco = 11
      , subs = [("left",tsub),("right",tsub)]
      }
    where tsub = tRef (Proxy @(RTree d1 a))



-- | A translator for displaying values with zero or more fields like tuples.
-- This function will error if called for a type that has more than one constructor!
tupleTranslator :: forall t. (BitPack t, WaveformG (Rep t ())) => Translator
tupleTranslator =
  Translator (bitsize (Proxy @t)) $ TProduct
    { start  = "("
    , sep    = ","
    , stop   = ")"
    , labels = []
    , preci  = -1
    , preco  = 11
    , subs   = fieldTranslatorsG @(Rep t ())
    }

-- | __NB__: The documentation only shows instances up to /3/-tuples. By
-- default, instances up to and including /12/-tuples will exist. If the flag
-- @large-tuples@ is set instances up to the GHC imposed limit will exist. The
-- GHC imposed limit is either 62 or 64 depending on the GHC version.
deriveWaveformTuples 2 MAX_TUPLE_SIZE
