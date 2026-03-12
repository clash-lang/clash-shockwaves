{- |
Copyright  :  (C) 2025-2026, QBayLogic B.V.
License    :  BSD2 (see the file LICENSE)
Maintainer :  QBayLogic B.V. <devops@qbaylogic.com>
Module      : Clash.Shockwaves
Description : Shockwaves: Typed waveforms

Shockwaves is a system for typed waveforms in Clash.
"Clash.Shockwaves" exports the minimum requirements for using Shockwaves.

For more options, see "Clash.Shockwaves.Waveform", "Clash.Shockwaves.Style",
"Clash.Shockwaves.LUT" and "Clash.Shockwaves.Trace".

For the HOWTO guides on using Shockwaves, check out
[the documentation in the GitHub repository](https://github.com/clash-lang/clash-shockwaves/blob/main/docs/howto/README.md).

Note: this exports the "Clash.Shockwaves.Trace" module, which creates name space
collisions with "Clash.Signal.Trace". Import qualified or selectively.
-}
module Clash.Shockwaves (
  -- * Waveform
  Waveform (styles),
  WaveStyle (..),

  -- * Tracing
  module Clash.Shockwaves.Trace,
  writeFileJSON,
) where

import Clash.Shockwaves.Internal.Types
import Clash.Shockwaves.Internal.Util
import Clash.Shockwaves.Internal.Waveform
import Clash.Shockwaves.Trace
