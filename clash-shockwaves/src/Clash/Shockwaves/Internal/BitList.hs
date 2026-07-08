{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeAbstractions #-}

{- |
Copyright  :  (C) 2025-2026, QBayLogic B.V.
License    :  BSD2 (see the file LICENSE)
Maintainer :  QBayLogic B.V. <devops@qbaylogic.com>

Dynamically sized bitvectors.
-}
module Clash.Shockwaves.Internal.BitList where

import qualified Clash.Class.BitPack as BP
import Clash.Prelude hiding (concat, drop, pack, split, take, unpack)
import Clash.Sized.Internal.BitVector hiding (unsafeMask)
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

-- | Return the length of the 'BitList'.
length :: BitList -> Int
length (BL _ _ l) = l

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
pack :: (BitPack a) => a -> BitList
pack = bvToBl . BP.pack

-- | Unpack a value from a 'BitList'.
unpack :: (BitPack a) => BitList -> a
unpack = BP.unpack . blToBv

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

-- | Check whether any of the bits in the `BitList` are undefined.
hasUndefined :: BitList -> Bool
hasUndefined (BL m _ _) = m /= 0

instance Bits BitList where
  -- binary operations are right-aligned when not equal in length
  -- & and | short circuit on unknowns (0 & x = 0, 1 | x = 1)
  (.&.) (BL ma ia la) (BL mb ib lb) = BL ((ma .&. mb) .|. (ma .&. ib) .|. (ia .&. mb)) (ia .&. ib) (max la lb)
  (.|.) (BL ma ia la) (BL mb ib lb) = BL ((ma .|. mb) .&. (mask l - v)) v l
   where
    l = max la lb
    v = ia .|. ib
  xor (BL ma ia la) (BL mb ib lb) = BL m (((ia `xor` ib) .|. m) - m) (max la lb)
   where
    m = ma .|. mb

  complement (BL m i l) = BL m (mask l `xor` (i .|. m)) l
  shift (BL m i l) a = BL (shift m a .&. mask l) (shift i a .&. mask l) l
  rotate (BL m i l) a =
    BL
      ((shift m a' .|. shift m (a' - l)) .&. mask l)
      ((shift i a' .|. shift i (a' - l)) .&. mask l)
      l
   where
    a' = a `mod` l
  bitSize (BL _ _ l) = l
  bitSizeMaybe (BL _ _ l) = Just l
  isSigned _ = False
  testBit (BL _ i _) = testBit i
  bit n = BL 0 (bit n) (n + 1)
  popCount (BL _ i _) = popCount i

mask :: Int -> Natural
mask l = (1 `shiftL` l) - 1

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
