{-|
Copyright  :  (C) 2025-2026, QBayLogic B.V.
License    :  BSD2 (see the file LICENSE)
Maintainer :  QBayLogic B.V. <devops@qbaylogic.com>

Some functions for creating signals for clocks and reset and enable signals.
-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE OverloadedStrings #-}

module Clash.Shockwaves.Internal.Trace.CRE where

import           Clash.Prelude hiding (traceSignal, register)
import           Clash.Explicit.Prelude (register,noReset)
import           Data.Typeable
import qualified Data.List as L
import           Data.Tuple.Extra (uncurry3)

import           Clash.Shockwaves.Waveform hiding (tConst)
import           Clash.Shockwaves.LUT
import           Clash.Shockwaves.Trace




-- | A type for displaying clock cycles.
-- The styles can be configured through style variables @clk_rst@, @clk_a@ and @clk_b@.
--
-- __NB__: This is not a traditional clock wave! The clock signal alternates
-- /every cycle/, rather than going high and low /within/ a cycle. 
data ClockWave = ClockWave Bool
               | ClockInit
  deriving (Generic,Typeable,BitPack,NFDataX)

-- | A type for displaying a reset signal.
-- The styles can be configured through style variables @reset_off@ and @reset_on@.
newtype ResetWave (dom::Domain) = ResetWave Bool
  deriving (Generic,Typeable,BitPack,NFDataX)

-- | A type for displaying an enable signal.
-- The styles can be configured through style variables @enable_off@ and @enable_on@.
newtype EnableWave = EnableWave Bool
  deriving (Generic,Typeable,BitPack,NFDataX)

-- | A type for displaying clock, reset and enable signals.
-- See 't:ClockWave', 't:ResetWave' and 't:EnableWave'.
-- It contains these signals as subsignals. The toplevel signal displays the clock
-- during normal operation, reset when it is active, and enable when it is low.
-- The combined style of both being active can be configured through the style
-- vairable @reset_on_enable_off@.
data CREWave dom = CREWave {clock::ClockWave, reset::ResetWave dom, enable::EnableWave}
  deriving (Generic,Typeable,BitPack,NFDataX)
  deriving Waveform via (WaveformForLUT (CREWave dom))

vConst :: Render -> Translator
vConst r = Translator 0 $ TConst $ tConst r
tConst :: Render -> Translation
tConst r = Translation r []

-- the render values used
clkI :: Render
clkI = Just ("DISABLED",WSVar "clk_rst" WSHidden,11)
clkA :: Render
clkA = Just ("",WSVar "clk_a" "#fff",11)
clkB :: Render
clkB = Just ("",WSVar "clk_b" "#83b",11)

rstOff :: Render
rstOff = Just ("DEASSERTED", WSVar "reset_off" WSHidden,11)
rstOn :: Render
rstOn = Just ("ASSERTED", WSVar "reset_on" WSWarn,11)
rstOn' :: Render
rstOn' = Just ("RESET", WSVar "reset_on" WSWarn,11)

enOn :: Render
enOn = Just ("ENABLED", WSVar "enable_on" WSHidden,11)
enOff :: Render
enOff = Just ("DISABLED", WSVar "enable_off" WSWarn,11)

rstAndDis :: Render
rstAndDis = Just ("DISABLED|RESET", WSVar "reset_on_enable_off" WSWarn,11)

-- | Control the styles of the clock wave through style variables
-- @clk_rst@, @clk_a@ and @clk_b@.
instance Waveform ClockWave where
  translator = Translator 2 $ TSum
    [ Translator 1 $ TSum
      [ vConst clkA
      , vConst clkB
      ]
    , vConst clkI
    ]

-- | Control the styles of the reset wave through style variables
-- @reset_on@ and @reset_off@.
instance (KnownDomain dom) => Waveform (ResetWave dom) where
  translator = Translator 1 $ TSum $ L.map vConst
    ( case resetPolarity @dom of
        SActiveHigh -> [rstOff,rstOn ]
        SActiveLow  -> [rstOn ,rstOff] )

-- | Control the styles of the enable wave through style variables
-- @enable_on@ and @enable_off@.
instance Waveform EnableWave where
  translator = Translator 1 $ TSum
    [ vConst enOff
    , vConst enOn
    ]

{- FOURMOLU_DISABLE -}
-- | Control the style of a combined disable and reset through style variable
-- @reset_on_enable_off@.
instance KnownDomain dom => WaveformLUT (CREWave dom) where
  translateL = translateWith displayL splitL
    where 
      displayL (CREWave c r (EnableWave e)) = case (c,isRst r,e) of
        (_              ,True,False) -> rstAndDis
        (_              ,True,_    ) -> rstOn'
        (_              ,_   ,False) -> enOff
        (ClockInit      ,_   ,_    ) -> clkI
        (ClockWave False,_   ,_    ) -> clkA
        (ClockWave True ,_   ,_    ) -> clkB
        where
          isRst (ResetWave r') = case resetPolarity @dom of
            SActiveHigh -> r'
            SActiveLow  -> not r'
{- FOURMOLU_ENABLE -}

-- | Produce an alternating signal for a clock.
clkSignal :: (KnownDomain dom) => Clock dom -> Signal dom ClockWave
clkSignal clk = s
  where
    s = register clk noReset enableGen ClockInit s'
    s' = next <$> s
    next val = case val of
      ClockInit -> ClockWave False
      ClockWave b -> ClockWave (not b)

-- | Trace a clock signal. Keep in mind that the clock has to be evaluated in order for
-- the signal to show up. Alternatively, use 'seq' to force evaluation.
--
-- The styles can be configured through style variables @clk_rst@, @clk_a@ and @clk_b@.
--
-- __NB__: This is not a traditional clock wave! The clock signal alternates
-- /every cycle/, rather than going high and low /within/ a cycle. 
traceClock :: (KnownDomain dom) => String -> Clock dom -> Clock dom
traceClock lbl clk = traceSignal lbl (clkSignal clk)
                     `seq` clk

-- | Trace a reset signal. Keep in mind that the reset has to be evaluated in order for
-- the signal to show up. Alternatively, use 'seq' to force evaluation.
--
-- The styles can be configured through style variables @reset_off@ and @reset_on@.
traceReset :: forall dom. (KnownDomain dom) => String -> Reset dom -> Reset dom
traceReset lbl rst = traceSignal lbl (ResetWave @dom <$> unsafeFromReset rst)
                     `seq` rst

-- | Trace an enable signal. Keep in mind that the enable has to be evaluated in order for
-- the signal to show up. Alternatively, use 'seq' to force evaluation.
--
-- The styles can be configured through style variables @enable_off@ and @enable_on@.
traceEnable :: (KnownDomain dom) => String -> Enable dom -> Enable dom
traceEnable lbl en = traceSignal lbl (EnableWave <$> fromEnable en)
                     `seq` en

-- | Create a signal displaying the clock, reset and enable signals.
-- 
-- Example:
--
-- > traceClockResetEnable "cre" myDesign clockGen resetGen enableGen
--
-- The style of a combined disable and reset can be configured through style variable 
-- @reset_on_enable_off@. For other options, see 'traceClock', 'traceReset' and
-- 'traceEnable'.
--
-- __NB__: This does not contain a traditional clock wave! The clock signal alternates
-- /every cycle/, rather than going high and low /within/ a cycle. 
traceClockResetEnable
  :: forall dom a. (KnownDomain dom)
  => String
  -> (Clock dom -> Reset dom -> Enable dom -> a)
  -> (Clock dom -> Reset dom -> Enable dom -> a)
traceClockResetEnable lbl f c r e = traceSignal lbl
                                     ( uncurry3 CREWave <$> bundle
                                       ( clkSignal c
                                       , ResetWave <$> unsafeFromReset r
                                       , EnableWave <$> fromEnable e
                                       ) :: Signal dom (CREWave dom) )
                                    `seq` f c r e

-- | Trace a hidden clock signal. See 'traceClock'.
traceHiddenClock :: (KnownDomain dom, HiddenClock dom) => String -> r -> r
traceHiddenClock lbl x = traceClock lbl hasClock `seq` x

-- | Trace a hidden reset signal. See 'traceReset'.
traceHiddenReset :: (KnownDomain dom, HiddenReset dom) => String -> r -> r
traceHiddenReset lbl x = traceReset lbl hasReset `seq` x

-- | Trace a hidden enable signal. See 'traceEnable'.
traceHiddenEnable :: (KnownDomain dom,HiddenEnable dom) => String -> r -> r
traceHiddenEnable lbl x = traceEnable lbl hasEnable `seq` x

-- | Trace hidden clock, reset and enable signals. See 'traceClockResetEnable'.
traceHiddenClockResetEnable :: (KnownDomain dom, HiddenClockResetEnable dom) => String -> r -> r
traceHiddenClockResetEnable lbl = hideClockResetEnable . traceClockResetEnable lbl . exposeClockResetEnable
