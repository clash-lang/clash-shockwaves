-- all you need for custom waveform implementations

{- |
Copyright  :  (C) 2025-2026, QBayLogic B.V.
License    :  BSD2 (see the file LICENSE)
Maintainer :  QBayLogic B.V. <devops@qbaylogic.com>
Module      : Clash.Shockwaves.Waveform
Description : Shockwaves tools for custom Waveform implementations

Everything needed to create custom implementations of 'Waveform'.
-}
module Clash.Shockwaves.Waveform (
  -- * The Waveform class
  Waveform (translator, constructorStyles),
  translate,
  translateBin,
  hasGeneratedLut,
  translateBinT,
  hasGeneratedLutT,

  -- * Translations
  Translation (..),
  Render,
  WaveStyle (..),
  Value,
  Prec,
  SubSignal,

  -- * Translators
  Translator (..),
  TranslatorVariant (..),

  -- ** Signal structure
  Structure (..),
  structure,
  structureT,
  fromTranslation,

  -- ** Translator-specific types
  NumberFormat (..),
  DecSpacer,
  HexSpacer,
  OctSpacer,
  BinSpacer,
  NoSpacer,
  SpacerEvery,
  ValuePart (..),
  BitPart (..),

  -- ** Creating Translators
  bitSize,
  pprintT,
  defaultTranslator,
  withConstructorStyles,
  inheritSingleFieldStyle,
  noConstructorSubsignals,
  renameFields,
  tRef,
  tDup,
  tStyled,
  tConst,

  -- * Special Waveform instances
  WaveformConst (..),
  WaveformForConst,
  WaveformForNumber (..),

  -- ** Creating special Waveform instances
  defaultTypeName,
) where

import Clash.Shockwaves.Internal.Translator
import Clash.Shockwaves.Internal.Types
import Clash.Shockwaves.Internal.Util

import Clash.Shockwaves.Internal.Waveform
