{- |
Copyright  :  (C) 2025-2026, QBayLogic B.V.
License    :  BSD2 (see the file LICENSE)
Maintainer :  QBayLogic B.V. <devops@qbaylogic.com>
Module      : Clash.Shockwaves.LUT
Description : Shockwaves tools for LUTs

Everything needed to create 'Clash.Shockwaves.Waveform' instances that use lookup tables.
-}
module Clash.Shockwaves.LUT (
  -- * WaveformLUT
  WaveformLUT (structureL, translateL),
  translateWith,
  renderWith,
  renderShow,
  translateAtomWith,
  translateAtomShow,
  translateAtomSigWith,
  translateAtomSigShow,
  noSplit,
  splitL,
  precL,
  WaveformForLUT (..),
  tLut,

  -- * Utility
  tFromVal,
  rFromVal,
  safeWHNF,
  safeVal,
  safeValOr,
  safeTranslation,
  errorT,
  errorR,

  -- * Standard Shockwaves types and functions
  Waveform,
  Translation (..),
  Value,
  WaveStyle (..),
  Prec,
  Structure (..),
  SubSignal,
  structure,
  structureT,
) where

import Clash.Shockwaves.Internal.Translator
import Clash.Shockwaves.Internal.Types
import Clash.Shockwaves.Internal.Util
import Clash.Shockwaves.Internal.Waveform
