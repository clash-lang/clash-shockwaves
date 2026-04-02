module Tests.Structure where

import Clash.Shockwaves.Internal.Types
import Data.Either (lefts)
import qualified Data.List as L
import Data.Map
import Prelude

-- Test whether a translation matches the provided structure
testStructure :: Structure -> Translation -> Either String ()
testStructure (Structure s) (Translation _ren subs) = res
 where
  res = case lefts $ L.map go subs of
    [] -> Right ()
    x : _ -> Left x
  go (name, trans) = case smap !? name of
    Just strct -> testStructure strct trans
    Nothing -> Left ("Unknown field " <> name)
  smap = fromList s
