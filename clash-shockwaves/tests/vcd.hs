
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE DataKinds #-}


module Main where

import Clash.Prelude
import Clash.Shockwaves
-- import Clash.Shockwaves.LUT
import Clash.Shockwaves.Trace as T

import Tests.Types

import qualified Data.Text as Text
-- import Data.Proxy
-- import Data.Typeable
import qualified Data.List as L

import System.Directory

createDomain vSystem{vName="Dom50", vPeriod=hzToPeriod 50e6}


undef :: a
undef = Clash.Prelude.undefined

{- FOURMOLU_DISABLE -}
tests :: [(String, R'->R')]
tests =
  [ test "S"  $ values [S,undef]
  , test "M"  $ values [Ma,Mb,Mc,undef]
  , test "F"  $ values [M True 3,M False 3,undef]
  , test "Op" $ values [True ://: (False ://: False), undef ://: (True ://: False), False ://: (True://:undef),undef]
  , test "St" $ values [St{b=3,a=False},St{a=undef,b=0},undef]
  , test "C"  $ values [Red,Green,Blue,undef]
  , test "Mix"$ values [A,B True,C False 1,D{x=True,y= -1},0 :**: (True ://: False),undef]
  , test "L"  $ values [La True False,Lb False True,undef]
  , test "Maybe" $ values [Nothing, Just True, undef]
  , test "Vec2"  $ values [True :> False :> Nil, undef :> undef :> Nil, undef]
  , test "Vec0"  $ values [Nil @Bool, undef]
  , test "Signed32" $ values [0::Signed 32,12345,1234567,-123456,-1234567]
  , test "Pointer16" $ values $ Pointer @16 <$> [0,1,2,3,undef]
  , test "NumRepU3" $ values $ NumRep <$> [0,1,3,4,7,undef :: Unsigned 3]
  , test "LittleEndian" $ values $ LittleEndian <$> [0,1,16,256,65536]
  , test "SumStruct" $ values $ [SSA $ Just True,SSB,SSC $ Left False, SSD]
  ]
{- FOURMOLU_ENABLE -}


type R = Unsigned 8
type R' = Signal Dom50 R

values :: (Waveform a,NFDataX a) => [a] -> String -> R' -> R'
values vals name i = o
  where
    o = seq x i
    x = T.traceSignal1 name $ fromList $ undef : (vals <> L.repeat undef)

test :: String -> (String -> R' -> R') -> (String,R'->R')
test name f = (name,f name)


topEntity ::
  Clock Dom50 ->
  Reset Dom50 ->
  Enable Dom50 ->
  R' ->
  R'
topEntity = exposeClockResetEnable runTests

runTests :: R' -> R'
runTests i = L.foldl go i tests'
  where
    tests' = L.map snd tests
    go i' f = f i'



main :: IO ()
main = do
  putStrLn "start"
  let out = topEntity (clockGen @Dom50) (resetGen @Dom50) enableGen $ T.traceSignal1 "helper" $ fromList $ L.repeat (3::Unsigned 8)
  vcddata <- T.dumpVCD (0, 100) out ["helper"]--(L.map fst tests)
  case vcddata of
    Left msg ->
      error msg
      putStrLn "finished with error"
    Right (vcd,meta) ->
      do createDirectoryIfMissing True "test/trace"
         writeFile     "test/trace/waveform_typetest.vcd" $ Text.unpack vcd
         writeFileJSON "test/trace/waveform_typetest.json" meta
         putStrLn "finished"
