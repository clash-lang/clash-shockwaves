{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeAbstractions #-}

{- |
Copyright  :  (C) 2025-2026, QBayLogic B.V.
License    :  BSD2 (see the file LICENSE)
Maintainer :  QBayLogic B.V. <devops@qbaylogic.com>

Dynamically sized bitvectors.
-}
module Clash.Shockwaves.Internal.BitList where

import Clash.Prelude hiding (concat, drop, split, take)
import Clash.Sized.Internal.BitVector
import Data.Aeson hiding (Value)
import Data.Aeson.Types (toJSONKeyText)
import Data.String (IsString (fromString))
import qualified Data.Text as Text

{- | A type like 'BitVector', but with a dynamic size.
It is meant to make type-independent handling of binary representations possible.
-}
data BitList = BL
  { unsafeMask :: !Natural
  , unsafeToNatural :: !Natural
  , bitLength :: !Int
  }
  deriving (Eq, Ord)

instance Show BitList where
  show BL{unsafeMask, unsafeToNatural, bitLength} = go bitLength unsafeMask unsafeToNatural []
   where
    go 0 _ _ s = s
    go n m0 v0 s =
      let
        (!v1, !vBit) = quotRem v0 2
        (!m1, !mBit) = quotRem m0 2
        !renderedBit = showBit mBit vBit
       in
        go (n - 1) m1 v1 (renderedBit : s)

    showBit 0 0 = '0'
    showBit 0 1 = '1'
    showBit _ _ = 'x'

-- | Convert a 'BitVector' into a 'BitList'.
bvToBl :: (KnownNat n) => BitVector n -> BitList
bvToBl (BV @n m i) = BL m i (natToNum @n)

{- | Convert a 'BitList' into a 'BitVector', provided that is has the right number
of bits
-}
blToBv :: forall n. (KnownNat n) => BitList -> BitVector n
blToBv (BL m i l) | natToNum @n == l = BV m i
blToBv _ = errorX "BitList does not match BitVector size"

-- | Pack a value into a 'BitList'.
binPack :: (BitPack a) => a -> BitList
binPack = bvToBl . pack

-- | Unpack a value from a 'BitList'.
binUnpack :: (BitPack a) => BitList -> a
binUnpack = unpack . blToBv

-- | Discard the /n/ most significant bits.
drop :: Int -> BitList -> BitList
drop x = snd . split x

-- | Take only the /n/ most significant bits.
take :: Int -> BitList -> BitList
take n (BL m i l)
  | n > l || n < 0 =
      error ("Attempt to take " <> show n <> " from BitList of size " <> show l)
  | otherwise = BL m' i' n
 where
  s = l - n
  m' = shiftR m s
  i' = shiftR i s

{- | Split a 'BitList' into the /n/ most significant bits,
and the rest of the bits
-}
split :: Int -> BitList -> (BitList, BitList)
split n bv@(BL mm ii l) = (a, b)
 where
  a@(BL m i _n) = take n bv
  m' = shiftL m (l - n)
  i' = shiftL i (l - n)
  b = BL (mm - m') (ii - i') (l - n)

-- | Concatenate two 'BitList's.
concat :: BitList -> BitList -> BitList
concat (BL ma ia la) (BL mb ib lb) = BL m i l
 where
  m = (ma `shiftL` lb) .|. mb
  i = (ia `shiftL` lb) .|. ib
  l = la + lb

-- | Take a range (exclusive) of a 'BitList'.
slice :: (Int, Int) -> BitList -> BitList
slice (from, to) = drop from . take to

-- | Convert a 'BitList' into an 'Integer' if it has no undefined bits.
toInteger :: BitList -> Maybe Integer
toInteger (BL m i _) | m == 0 = Just $ fromIntegral i
toInteger _ = Nothing

instance Semigroup BitList where
  (<>) = concat

instance ToJSON BitList where
  toJSON = toJSON . show

instance ToJSONKey BitList where
  toJSONKey = toJSONKeyText (Text.pack . show)

{- FOURMOLU_DISABLE -}
-- | When converting from a string, `0` and `1` are interpreted as bits, and
-- `_` is treated as a spacer (is ignored). Any other characters are interpreted
-- as undefined bits.
instance IsString BitList where
  fromString ss = go ss (BL 0 0 0)
    where
      go ""       bl         = bl
      go ('_': s) bl         = go s bl
      go ('0': s) (BL m i l) = go s (BL (2*m  ) (2*i  ) (l+1))
      go ('1': s) (BL m i l) = go s (BL (2*m  ) (2*i+1) (l+1))
      go ( _ : s) (BL m i l) = go s (BL (2*m+1) (2*i  ) (l+1))
{- FOURMOLU_ENABLE -}
