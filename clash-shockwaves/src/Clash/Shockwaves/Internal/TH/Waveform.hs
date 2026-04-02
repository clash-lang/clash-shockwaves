{- |
Copyright  :  (C) 2025-2026, QBayLogic B.V.
License    :  BSD2 (see the file LICENSE)
Maintainer :  QBayLogic B.V. <devops@qbaylogic.com>

A TH function for deriving 'Clash.Shockwaves.Waveform' for tuples.
-}
module Clash.Shockwaves.Internal.TH.Waveform where

import Control.Monad (replicateM)
import Language.Haskell.TH
import Prelude

{- | Derive 'Clash.Shockwaves.Waveform' implementations for tuples in the
specified range.
-}
deriveWaveformTuples :: Int -> Int -> DecsQ
deriveWaveformTuples minSize maxSize = do
  let waveform = ConT $ mkName "Waveform"

  allNames <- replicateM maxSize (newName "a")

  return $ flip map [minSize .. maxSize] $ \tupleNum ->
    let names = take tupleNum allNames
        vs = map VarT names
        tuple = foldl AppT (TupleT tupleNum) vs

        context = map (waveform `AppT`) vs
        instTy = AppT waveform tuple

        translatorE = AppTypeE (VarE $ mkName "tupleTranslator") tuple

        translator =
          FunD
            (mkName "translator")
            [ Clause
                []
                (NormalB translatorE)
                []
            ]
     in InstanceD Nothing context instTy [translator]
