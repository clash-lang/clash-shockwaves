{- |
Copyright  :  (C) 2025-2026, QBayLogic B.V.
License    :  BSD2 (see the file LICENSE)
Maintainer :  QBayLogic B.V. <devops@qbaylogic.com>
Module      : Clash.Shockwaves.BitList
Description : Dynamically sized binary representations

Various functions for dealing with dynamically sized binary representations of data.
-}
module Clash.Shockwaves.BitList (
  BitList,

  -- * Modifying BitLists
  take,
  drop,
  split,
  concat,
  slice,

  -- * Using BitList with BitVector
  bvToBl,
  blToBv,
  binPack,
  binUnpack,

  -- * Using BitList as a number
  toInteger,
) where

import Clash.Shockwaves.Internal.BitList
