
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-incomplete-uni-patterns #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE CPP #-}

import Prelude

import Test.Tasty
import Test.Tasty.HUnit

import Clash.Shockwaves.Internal.Types
import Clash.Shockwaves.Internal.Util
-- import Clash.Shockwaves.Internal.Translator
import Clash.Shockwaves.Internal.Waveform
import Clash.Prelude
import qualified Data.List as L
import qualified Data.Map as M
import Data.Bifunctor (second)
import Data.Maybe (fromMaybe)

import Tests.Structure
import Tests.Types

main :: IO ()
main = defaultMain tests

{-

- test testStructure with some cases
- test that for all types, for all values, the translation matches the structure
- test that for some complex values, the render string is exactly as expected
- test that for all types, for some values, the output structure and style is exactly as expected
- test that LUT types actually produce LUT tables, even when nested
- test that all subvalues get added to the type tables?

-}


isR :: Either String () -> Assertion
isR x = case x of
  Right () -> return ()
  Left msg -> assertFailure msg

isL :: Either String () -> Assertion
isL x = case x of
  Left _ -> return ()
  Right () -> assertFailure "passed, but should have failed"

tests :: TestTree
tests = testGroup "Tests" [testStructureTest,structureTest,rawStructureTest,renderTest,translationTest,lutTest]

undef :: a
undef = Clash.Prelude.undefined


{- FOURMOLU_DISABLE -}
{-

Test format:
  `isR/isL $ testStructure structure translation`
to test if `testStructure` accurately returns whether
the translation is a subset of the provided structure.

-}
testStructureTest :: TestTree
testStructureTest = testGroup "TEST testStructure FUNCTION"
  [ testCase "is empty, get empty"  $ isR $ testStructure
    (Structure           [])
    (Translation Nothing [])
  , testCase "is empty, get some"   $ isL $ testStructure
    (Structure           [                            ])
    (Translation Nothing [("a",Translation Nothing [])])
  , testCase "is some, get that"    $ isR $ testStructure
    (Structure           [("a",Structure           [])])
    (Translation Nothing [("a",Translation Nothing [])])
  , testCase "is some, get none"    $ isR $ testStructure
    (Structure           [("a",Structure           [])])
    (Translation Nothing [                            ])
  , testCase "is some, get other"   $ isL $ testStructure
    (Structure           [("a",Structure           [])])
    (Translation Nothing [("b",Translation Nothing [])])
  , testCase "recursive true"       $ isR $ testStructure
    (Structure           [ ("a",Structure           [])
                         , ("b",Structure           [ ("ba",Structure [])
                                                    , ("bb",Structure [])])])
    (Translation Nothing [ ("b",Translation Nothing [ ("ba",Translation Nothing [])
                                                    , ("bb",Translation Nothing [])])])
  , testCase "recursive false"      $ isL $ testStructure
    (Structure           [ ("a",Structure           [])
                         , ("b",Structure           [ ("ba",Structure [])
                                                    , ("bb",Structure [])])])
    (Translation Nothing [ ("b",Translation Nothing [ ("ba",Translation Nothing [])
                                                    , ("bc",Translation Nothing [])])])
  ]
{- FOURMOLU_ENABLE -}







testAll :: ShowX a => (a -> Assertion) -> [a] -> [TestTree]
testAll f = L.map go
  where go x = testCase (showX x) (f x)

testS :: Waveform a => a -> Assertion
testS (x::a) = isR $ testStructure (structure @a) $ translate x

{- FOURMOLU_DISABLE -}
{-

For all listed values, ensure that the translation is a subset of the
structure of the translator.

-}
structureTest :: TestTree
structureTest = testGroup "TRANSLATION MATCHES TRANSLATOR STRUCTURE"
  [ testGroup "S"  $ testAll testS [S,undef]
  , testGroup "M"  $ testAll testS [Ma,Mb,Mc,undef]
  , testGroup "F"  $ testAll testS [M True 3,M False 3,undef]
  , testGroup "Op" $ testAll testS [True ://: (False ://: False), undef ://: (True ://: False), False ://: (True://:undef),undef]
  , testGroup "St" $ testAll testS [St{b=3,a=False},St{a=undef,b=0},undef]
  , testGroup "C"  $ testAll testS [Red,Green,Blue,undef]
  , testGroup "Mix"$ testAll testS [A,B True,C False 1,D{x=True,y= -1},0 :**: (True ://: False),undef]
  , testGroup "L"  $ testAll testS [La True False,Lb False True,undef]
  , testGroup "Maybe" $ testAll testS [Nothing, Just True, undef]
  , testGroup "Vec 2" $ testAll testS [True :> False :> Nil, undef :> undef :> Nil, undef]
  , testGroup "Vec 0" $ testAll testS [Nil @Bool, undef]
  , testGroup "Pointer"   $ testAll testS [Pointer @32 0, Pointer 1, Pointer 2, Pointer undef, undef]
  , testGroup "NumRep"    $ testAll testS $ NumRep <$> [0,1,3,4,7 :: Unsigned 3]
  , testGroup "SumStruct" $ testAll testS $ [SSA $ Just True, SSB, SSC $ Left False, SSD]
  ]
{- FOURMOLU_ENABLE -}

--

struct :: forall a. Waveform a => (Structure -> Int) -> Assertion
struct p = pat p $ structure @a

pattern Q :: [(SubSignal, Structure)] -> Structure
pattern Q l <- Structure l

{-

Test whether the structure is as expected

-}
rawStructureTest :: TestTree
rawStructureTest = testGroup "STRUCTURE AS EXPECTED"
  [ testCase "SumStruct" $ struct @SumStruct (\(Q ["sub" :@ Q ["Just.0" :@ _, "Left" :@ _, "Right" :@ _],"B" :@ Q [], "D" :@ Q []]) -> 0)
  ]

--

renders :: (Waveform a, ShowX a) => [a] -> [String] -> [TestTree]
renders xs = L.zipWith go rs'
  where
    getRen (Translation Nothing _) = ""
    getRen (Translation (Just (s,_,_)) _) = s
    rs' = L.map (\x -> (showX x, getRen $ translate x)) xs
    go (n,x) y = testCase n $ x @?= y

{- FOURMOLU_DISABLE -}
-- A partially undefined vector spine will result in different pack values,
-- and thus different translations
#if MIN_VERSION_clash_prelude(1,8,5)
#define VECSPINE "True :> undefined :> Nil"
#else
#define VECSPINE "undefined :> undefined :> Nil"
#endif
{- FOURMOLU_ENABLE -}

{- FOURMOLU_DISABLE -}
{-

Tests take the format
  `renders [values] [string representations]`
to test if the render value is as expected.

-}
renderTest :: TestTree
renderTest = testGroup "RENDERED STRING IS CORRECT"
  [ testGroup "S"  $ renders [ S , undef]
                             ["S","S"   ]
  , testGroup "M"  $ renders [ Ma , Mb , Mc , undef     ]
                             ["Ma","Mb","Mc","undefined"]
  , testGroup "F"  $ renders [ M True (-3) , M False 3 , undef     ]
                             ["M True (-3)","M False 3","M undefined undefined"]
  , testGroup "Op" $ renders [ True ://: (False ://: False) , undef     ://: (True ://: False) , False ://: (True ://: undef)     , undef                                     ]
                             ["True ://: (False ://: False)","undefined ://: (True ://: False)","False ://: (True ://: undefined)","undefined ://: (undefined ://: undefined)"]
  , testGroup "St" $ renders [ St{b=3,a=False}      , St{a=undef,b=0}          , undef     ]
                             ["St{a = False, b = 3}","St{a = undefined, b = 0}","St{a = undefined, b = undefined}"]
  , testGroup "C"  $ renders [ Red , Green , Blue , undef     ]
                             ["Red","Green","Blue","undefined"]
  , testGroup "Mix"$ renders [ A , B True , C False 1 , D{x=True,y= -1}     , 0 :**: (True ://: False) , undef     ]
                             ["A","B True","C False 1","D{x = True, y = -1}","0 :**: (True ://: False)","undefined"]
  , testGroup "L"  $ renders [ La True False  , Lb False True  , undef     ]
                             ["True <A> False","False <B> True","undefined"]
  , testGroup "Maybe" $ renders [ Nothing , Just True , undef     ]
                                ["Nothing","Just True","undefined"]
  , testGroup "Vec 2" $ renders [ True :> False :> Nil , undef     :> undef     :> Nil , True :> undef, undef                         ]
                                ["True :> False :> Nil","undefined :> undefined :> Nil", VECSPINE     ,"undefined :> undefined :> Nil"]
  , testGroup "Vec 0" $ renders [ Nil @Bool, undef]
                                ["Nil"     ,"Nil" ]
  , testGroup "Maybe L" $ renders [ Just (La False False)  ,  Just undef     , undef     ]
                                  ["Just (False <A> False)", "Just undefined","undefined"]
  , testGroup "Signed 32" $ renders [ 0 ,  12345 ,   -123456789 :: Signed 32]
                                    ["0","12_345","-123_456_789"            ]
  , testGroup "Pointer 16" $ renders (Pointer @16 <$> [    0 ,       1 ,       2 ])
                                                      ["NULL","0X00_01","0X00_02"]
  , testGroup "NumRep U3" $ renders [NumRep (3::Unsigned 3)]
                                    ["{3, odd=True}"       ]
  , testGroup "LittleEndian" $ renders (LittleEndian <$> [             0 ,             1 ,            16 ,           256 ,         65536 ])
                                                         ["0Xxe_00_00_00","0Xxe_01_00_00","0Xxe_10_00_00","0Xxe_00_01_00","0Xxe_00_00_01"]
  ]
{- FOURMOLU_ENABLE -}









data T = T (String,WaveStyle) [(String,T)] deriving (Show)

pattern (:@) :: a -> b -> (a,b)
pattern (:@) x y <- (x,y)


toT :: Translation -> T
toT (Translation ren subs) = T d $ L.map (second toT) subs
  where d = case ren of
          Just (v,s,_) -> (v,s)
          Nothing -> ("",WSNormal)


pat :: Show t => (t -> Int) -> t -> Assertion
pat f v = case safeVal (f v) of
  Right _ -> return ()
  Left e -> assertFailure $ show v <> ": " <> fromMaybe "error" e

pats :: (Waveform a, ShowX a) => [(a,T->Int)] -> [TestTree]
pats = L.map (uncurry go)
  where
    go :: (Waveform a, ShowX a) => a -> (T -> Int) -> TestTree
    go x f = testCase (showX x) $ pat f $ toT $ translate x

{- FOURMOLU_DISABLE -}
{-

Tests take the format
  `pats [(value,pattern)]`
where a pattern is a lambda function that matches a specific input and returns 0:
  `\(value pattern)->0`
to test if the translation is as expected.

`a :@ b` is equivalent to `(a,b)` and only exists to make the pattern more readable.

-}
translationTest :: TestTree
translationTest = testGroup "TRANSLATION STRUCTURE/STYLE IS CORRECT"
  [ testGroup "S"  $ pats
    [ (S                            , \( T _ []                                                                 )->0)
    , (undef                        , \( T _ []                                                                 )->0) ]
  , testGroup "M"  $ pats
    [ (Ma                           , \( T _ ["Ma":@T ("Ma",_) []]                                              )->0)
    , (Mb                           , \( T _ ["Mb":@T _        []]                                              )->0)
    , (undef                        , \( T _ []                                                                 )->0) ]
  , testGroup "F"  $ pats
    [ (M True 3                     , \( T _ ["0":@T _ [],"1":@T _ []]                                          )->0)
    , (undef                        , \( T _ ["0":@T _ [],"1":@T _ []]                                          )->0) ]
  , testGroup "Op" $ pats
    [ (True ://: (False ://: False) , \( T _ ["0":@T _ _,"1":@T _ ["0":@T _ _, "1":@T _ _]]                     )->0)
    , (undef                        , \( T _ ["0":@T _ _,"1":@T _ ["0":@T _ _, "1":@T _ _]]                     )->0) ]
  , testGroup "St" $ pats
    [ (St{b=3,a=False}              , \( T _ ["a":@T _ [],"b":@T _ []]                                          )->0)
    , (undef                        , \( T _ ["a":@T _ [],"b":@T _ []]                                          )->0) ]
  , testGroup "C"  $ pats
    [ (Red                          , \( T ("Red"  ,WSInherit 0) ["Red"  :@T ("Red"  ,WSVar "red"   "red" ) []] )->0)
    , (Green                        , \( T ("Green",WSInherit 0) ["Green":@T ("Green",WSVar "green" "lime") []] )->0) ]
  , testGroup "L"  $ pats
    [ (La True False                , \( T (_,"red") ["La":@T (_,"red") ["0":@ _,"1":@ _]]                      )->0)
    , (undef                        , \( T _         []                                                         )->0) ]
  , testGroup "Maybe" $ pats
    [ (Nothing                      , \( T _ []                                                                 )->0)
    , (Just True                    , \( T _ ["Just.0":@ _]                                                     )->0)
    , (undef                        , \( T _ []                                                                 )->0) ]
  , testGroup "Vec 2" $ pats
    [ (True  :> False :> Nil        , \( T _ ["0":@ _,"1":@ _]                                                  )->0)
    , (undef :> undef :> Nil        , \( T _ ["0":@ _,"1":@ _]                                                  )->0)
    , (True  :> undef               , \( T _ ["0":@ _,"1":@ _]                                                  )->0)
    , (undef                        , \( T _ ["0":@ _,"1":@ _]                                                  )->0) ]
  , testGroup "NumRep U3" $ pats
    [ (NumRep (1::Unsigned 3)       , \( T _ ["bin":@ _,"oct":@ _, "hex":@ _, "unsigned":@ _, "signed":@ _,"odd":@ _] )->0)]
  ]
{- FOURMOLU_ENABLE -}

{- FOURMOLU_DISABLE -}
{-
Test whether the LUT table contains the expected values after
calling `addValue`

-}
lutTest :: TestTree
lutTest = testGroup "LUT VALUES ARE STORED"
  [ testCase "True <A> True"        $ apply (addValue (La True True)       ) M.empty @?= M.fromList [(typeName @L,M.fromList [("011",translate $ La True True)])]
  , testCase "Just (True <A> True)" $ apply (addValue (Just $ La True True)) M.empty @?= M.fromList [(typeName @L,M.fromList [("011",translate $ La True True)])]
  , testCase "undefined @L"         $ apply (addValue (undef @L)           ) M.empty @?= M.fromList [(typeName @L,M.fromList [("xxx",translate $ undef @L    )])]
  , testCase "Just (undefined @L)"  $ apply (addValue (Just $ undef @L)    ) M.empty @?= M.fromList [(typeName @L,M.fromList [("xxx",translate $ undef @L    )])]
  , testCase "undefined @(Maybe L)" $ apply (addValue (undef @(Maybe L))   ) M.empty @?= M.empty
  ]
  where apply fs m = L.foldl (flip ($)) m fs
{- FOURMOLU_ENABLE -}
