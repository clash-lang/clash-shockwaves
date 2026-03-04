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

import Clash.Prelude
import Clash.Shockwaves.Internal.Types
import Control.DeepSeq (NFData, force)
import Control.Exception (SomeException, catch, evaluate)
import Control.Exception.Base (Exception (toException))
import Data.Aeson (ToJSON, encodeFile)
import Data.Char (isAlpha)
import qualified Data.List as L
import Data.List.Split (chunksOf)
import Data.Map (Map)
import qualified Data.Map as M
import Data.Maybe (fromMaybe, listToMaybe)
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
bitsize :: (BitPack a) => Proxy a -> Int
bitsize (_ :: Proxy a) = fromInteger $ natVal $ Proxy @(BitSize a)

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

{- | Obtain the name of a type from a proxy value.
The name consists of a unique fingerprint (which is safe to use)
and a human readable representation of the type (which may not be unique
if multiple sources define the same types).
-}
typeNameP :: (Typeable a) => Proxy a -> TypeName
typeNameP p = show (typeRepFingerprint r) <> ":" <> show r
 where
  r = typeRep p

-- | Shorthand function for obtaining the runtime 'String' of a type level Symbol.
sym :: forall s. (KnownSymbol s) => String
sym = symbolVal (Proxy @s)

{- | Check if a value is completely defined.
If not, optionally return an error message.
-}
safeVal :: (NFData a) => a -> Either (Maybe Value) a
safeVal x =
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

{- | Check if a value is completely defined.
If not, return the default value provided.
-}
safeValOr :: (NFData a) => a -> a -> a
safeValOr y x = case safeVal x of
  Right x' -> x'
  Left _e -> y

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
