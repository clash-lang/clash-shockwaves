{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}

{- |
Copyright  :  (C) 2025-2026, QBayLogic B.V.
License    :  BSD2 (see the file LICENSE)
Maintainer :  QBayLogic B.V. <devops@qbaylogic.com>

Some small helper functions.
-}
module Clash.Shockwaves.Internal.Util where

import Clash.Prelude hiding (sub)
import Clash.Shockwaves.Internal.Types
import Clash.Shockwaves.Style (RGB (..))
import Control.DeepSeq (NFData, force)
import Control.Exception (SomeException, catch, evaluate)
import Control.Exception.Base (Exception (toException))
import Data.Aeson (ToJSON, encodeFile)
import Data.Char (isAlpha)
import qualified Data.List as L
import Data.List.Split (chunksOf)
import Data.Map (Map)
import qualified Data.Map as M
import Data.Maybe (fromMaybe, isJust, listToMaybe)
import Data.Proxy
import Data.Typeable
import GHC.IO (unsafeDupablePerformIO)

{- | A folding function like scan that has separate output and continue values.
The dataflow looks like:

>    [ b,    b',   b'' ]
>      v     v     v
> a > [f] > [f] > [f] > _
>      v     v     v
>    [ c,    c',   c'' ]
-}
carryFoldl :: (a -> b -> (a, c)) -> a -> [b] -> [c]
carryFoldl _ _ [] = []
carryFoldl f i (x : xs) = y : carryFoldl f i' xs
 where
  (i', y) = f i x

-- | Insert value into dictionary if the key was not yet present.
insertIfMissing :: (Ord k) => k -> v -> Map k v -> Map k v
insertIfMissing k v = M.alter (Just . fromMaybe v) k

-- | Re-export of 'Data.Aeson.encodeFile' for cleaner naming in tracing functions.
writeFileJSON :: forall a. (ToJSON a) => FilePath -> a -> IO ()
writeFileJSON = encodeFile

-- | Returns the 'BitSize' of a type as a runtime 'Int'.
bitSize :: forall a. (BitPack a) => Int
bitSize = fromInteger $ natVal $ Proxy @(BitSize a)

-- | Wrap parentheses around a value.
parenthesize :: Value -> Value
parenthesize n = "(" <> n <> ")"

-- | Add parentheses around an identifier if it is an operator.
safeName :: Value -> Value
safeName n = if isAlpha $ fromMaybe '_' $ listToMaybe n then n else parenthesize n

{- | Join a list of values with a separator. If the list is empty, an empty
value is returned.
-}
joinWith :: Value -> [Value] -> Value
joinWith s (x : y : r) = x <> s <> joinWith s (y : r)
joinWith _ [x] = x
joinWith _ [] = ""

{- | Obtain the default name of a type.
The name consists of a unique fingerprint (which is safe to use)
and a human readable representation of the type (which may not be unique
if multiple sources define the same types).
-}
defaultTypeName :: forall a. (Typeable a) => TypeName
defaultTypeName = show (typeRepFingerprint r) <> ":" <> show r
 where
  r = typeRep (Proxy @a)

-- | Shorthand function for obtaining the runtime 'String' of a type level Symbol.
sym :: forall s. (KnownSymbol s) => String
sym = symbolVal (Proxy @s)

{- | Check if a value is completely defined.
If not, optionally return an error message.
-}
safeNFErr :: (NFData a) => a -> Either (Maybe Value) a
safeNFErr x =
  unsafeDupablePerformIO
    $ catch
      ( evaluate
          . unsafeDupablePerformIO
          $ catch
            (evaluate . force $ Right x)
            ( \(e :: SomeException) ->
                return $ Left (Just $ show $ toException e)
            )
      )
      (\(XException e) -> return $ Left (Just e))

-- | Check if a value is completely defined.
safeNF :: (NFData a) => a -> Maybe a
safeNF = either (const Nothing) Just . safeNFErr

{- | Check if a value is completely defined.
If not, return the default value provided.
-}
safeNFOr :: (NFData a) => a -> a -> a
safeNFOr y x = fromMaybe y $ safeNF x

-- | Evaluate to WHNF. If this fails, return a default value.
safeWHNF :: a -> Maybe a
safeWHNF x =
  unsafeDupablePerformIO
    $ catch
      ( evaluate
          . unsafeDupablePerformIO
          $ catch
            (evaluate (x `seq` Just x))
            ( \(_ :: SomeException) ->
                return Nothing
            )
      )
      (\(XException _e) -> return Nothing)

-- | Insert spacers in a number value
applySpacer :: NumberSpacer -> Value -> Value
applySpacer Nothing v = v
applySpacer (Just (0, _)) v = v
applySpacer (Just (n, s)) v = v'
 where
  chunks = chunksOf (fromIntegral n) $ L.reverse v
  v' =
    L.reverse
      ( if L.last chunks == "-"
          then
            joinWith (L.reverse s) (L.init chunks) <> "-"
          else
            joinWith (L.reverse s) chunks
      )

-- | Replace subsignal labels with numbers
enumLabel :: [(SubSignal, a)] -> [(SubSignal, a)]
enumLabel = L.zipWith (\i (_, t) -> (show i, t)) [(0 :: Integer) ..]

-- | Render some error message. The precedence is set to 11 (i.e. an atomic).
errorR :: Value -> Render
errorR v = Just (v, WSError, 11)

-- | Create a translation from an error message using 'errorR'.
errorT :: Value -> Translation
errorT e = Translation (errorR e) []

-- | Add a translator by name to the type map.
addType :: String -> Translator -> (TypeMap -> TypeMap)
addType = M.insert

-- | `zipWith` variant that errors on lists of different length
erroringZipWith :: String -> (a -> b -> c) -> [a] -> [b] -> [c]
erroringZipWith _ _ [] [] = []
erroringZipWith e f (x : xs) (y : ys) = f x y : erroringZipWith e f xs ys
erroringZipWith e _ _ _ = error e

-- | 'head' but without complaints
unsafeHead :: [a] -> a
unsafeHead (x : _) = x
unsafeHead _ = error "empty list has no head"

{- | Debug function for pretty printing t'Translator's.
The output of this function may change. It is merely intended as a debug tool
when creating and modifying translators.
-}
pprintT :: Translator -> String
pprintT = pprintT' 0
 where
  pprintT' :: Int -> Translator -> String
  pprintT' indent (Translator w v) =
    space
      <> ( case v of
             TRef n _ref ->
               trans "Ref" <> " " <> n
             TLut n sLut _ref ->
               trans "Lut" <> " (" <> (if isJust sLut then "static" else "generated") <> ") " <> n
             TSum ts ->
               (trans "Sum" <> "\n")
                 <> joinWith "\n" (L.map (pprintT' indent') ts)
             TAdvancedSum{defTrans, rangeTrans} ->
               (trans "AdvancedSum" <> "\n")
                 <> (space' <> "default" <> "\n")
                 <> (pprintT' indent' defTrans <> "\n")
                 <> (space' <> "subs" <> "\n")
                 <> joinWith "\n" (L.map (pprintT' indent') (defTrans : L.map snd rangeTrans))
             TProduct{subs, start, sep, stop} ->
               (trans "Product" <> " ()" <> start <> "/" <> sep <> "/" <> stop <> ")")
                 <> L.concatMap (\(s, t) -> "\n" <> space' <> s <> "\n" <> pprintT' indent' t) subs
             TArray{sub, len, start, sep, stop} ->
               ( (trans "Array" <> " len:" <> show len)
                   <> (" (" <> start <> "/" <> sep <> "/" <> stop <> ")\n")
               )
                 <> pprintT' indent' sub
             TAdvancedProduct{sliceTrans} ->
               (trans "AdvancedProduct" <> "\n")
                 <> joinWith "\n" (L.map (pprintT' indent' . snd) sliceTrans)
             TDuplicate n t ->
               (trans "Dup" <> space' <> n <> "\n")
                 <> pprintT' indent' t
             TStyled sty t ->
               (trans "Styled" <> " " <> showStyle sty <> "\n")
                 <> pprintT' indent' t
             TChangeBits{sub} ->
               (trans "ChangeBits" <> "\n")
                 <> pprintT' indent' sub
             TNumber{format} ->
               trans "Number" <> " " <> show format
             TConst (Translation val _) ->
               trans "Const" <> " " <> case val of
                 Just (val', _, _) -> val'
                 _ -> "_"
         )
   where
    space = L.replicate indent ' '
    space' = L.replicate (indent + 2) ' '
    trans s = s <> "[" <> show w <> "]"
    indent' = indent + 4
    showStyle = \case
      WSDefault -> "Default"
      WSError -> "Error"
      WSHidden -> "Hidden"
      WSInherit n -> "Inherit " <> show n
      WSNormal -> "Normal"
      WSWarn -> "Warn"
      WSUndef -> "Undef"
      WSHighImp -> "HighImp"
      WSDontCare -> "DontCate"
      WSWeak -> "Weak"
      WSColor (RGB r g b) -> "Color (" <> show r <> "," <> show g <> "," <> show b <> ")"
      WSVar var dflt -> "$" <> var <> "/" <> showStyle dflt
