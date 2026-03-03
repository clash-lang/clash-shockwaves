{-|
Copyright  :  (C) 2025-2026, QBayLogic B.V.
License    :  BSD2 (see the file LICENSE)
Maintainer :  QBayLogic B.V. <devops@qbaylogic.com>

Code for rendering values using the translators specified.
Values are constructed from their subvalues.

-}

{-# LANGUAGE OverloadedStrings #-}

module Clash.Shockwaves.Internal.Translator where

import           Clash.Prelude hiding (sub)
import           Clash.Shockwaves.Internal.BitList
import qualified Clash.Shockwaves.BitList as BL
import           Clash.Shockwaves.Internal.Types
import qualified Data.List as L
import qualified Data.Map as M
import           Data.Maybe (fromMaybe, isJust)
import           Data.Bifunctor (first)
import           Clash.Shockwaves.Internal.Util
import           Data.List.Extra (chunksOf)
import           Numeric (showHex)
import           Math.NumberTheory.Logarithms (intLog2)
import           Data.Tuple.Extra (second)



-- | Apply a 'WaveStyle' to a 't:Translation' value. Only replaces 'WSDefault'.
applyStyle :: WaveStyle -> Translation -> Translation
applyStyle s (Translation r sb) = Translation (applyStyleR s r) sb

-- | Apply a 'WaveStyle' to a 'Render' value. Only replaces 'WSDefault'.
applyStyleR :: WaveStyle -> Render -> Render
applyStyleR s (Just (l,WSDefault,p)) = Just (l,s,p)
applyStyleR _ r = r







-- | Apply a precedence value to a 't:Translation'.
-- If the precedence is higher or equal to that of the current value,
-- it is wrapped in parentheses.
applyPrec :: Prec -> Translation -> Translation
applyPrec p (Translation r s) = Translation (applyPrecR p r) s

-- | Apply a precedence value to a 'Render'.
-- If the precedence is higher or equal to that of the current value,
-- it is wrapped in parentheses.
applyPrecR :: Prec -> Render -> Render
applyPrecR p (Just (v,s,p')) = if p'>p then Just (v,s,p')
                               else Just (parenthesize v, s, 11)
applyPrecR _ Nothing = Nothing


-- | Apply a precedence value to a list of subsignal translations.
-- If the precedence is higher or equal to that of the current value,
-- it is wrapped in parentheses.
applyPrecs :: Prec -> [(a, Translation)] -> [(a, Translation)]
applyPrecs p = L.map (second (applyPrec p))


-- | Get the value of a 't:Translation'. If the value is not defined,
-- return @{value missing}@.
getVal :: Translation -> Value
getVal t = case t of
              Translation (Just (v,_,_)) _ -> v
              _ -> "{value missing}"


-- | Remove subsignal translators that do not have a subsignal name.
filterSignals :: [(SubSignal,Translation)] -> [(SubSignal,Translation)]
filterSignals = L.filter ((/="") . fst)

{- FOURMOLU_DISABLE -}
-- | Change bits using 'BitPart'.
changeBits :: BitPart -> BitList -> BitList
changeBits (BPConcat bps) bin = L.foldl (<>) "" $ L.map (`changeBits` bin) bps
changeBits (BPLit bl)    _bin = bl
changeBits (BPSlice s)    bin = BL.slice s bin
{- FOURMOLU_ENABLE -}




{- FOURMOLU_DISABLE -}
-- | Decode a string of bits into an unsigned integer.
decodeUns :: Integer -> String -> Maybe Integer
decodeUns k ""      = Just k
decodeUns k ('0':r) = decodeUns (k*2) r
decodeUns k ('1':r) = decodeUns (k*2+1) r
decodeUns _ _       = Nothing

-- | Decode a string of bits into a signed integer.
decodeSig :: String -> Maybe Integer
decodeSig ""      = Just 0
decodeSig ('0':r) = decodeUns 0 r
decodeSig ('1':r) = decodeUns (-1) r
decodeSig _       = Nothing
{- FOURMOLU_ENABLE -}

-- | Complete a translation based on already translated subsignals.
--
-- The exact behaviour is non-trivial.
-- Translators that require special translation ('TRef','TLut','TNumber')
-- cannot be translated. If a single subsignal is provided with label `""`,
-- this translation is used as if it was the result of the translation.
-- Otherwise, an error is raised.
--
-- 'TSum', 'TProduct', 'TArray' and 'TConst' render a value as expected based on
-- the subtranslations. Note for TSum that this is a list containing only the
-- translation of the variant used, i.e. it behaves like 'TRef', 'TLut' and 'TNumber'.
--
-- Advanced translators are not supported.
--
-- The final two variants, 'TStyled' and 'TDuplicate' are considered /wrappers/
-- and translate the value recursively.
translateFromSubs :: Translator -> [(SubSignal,Translation)] -> Translation
translateFromSubs (Translator _ translator) subs = case translator of
  TRef{} -> case subs of
    [("",t)] -> t
    _ -> errorX "Ref should only appear as a nested type that is translated through split; for referenced types, modify Waveform.translate"
  TLut _ _ -> case subs of
    [("",t)] -> t
    _ -> errorX "LUT translators require a custom implementation of Waveform.translate that does not call render"
  TNumber{} -> case subs of
    [("",t)] -> t
    _ -> errorX "Number translators require a custom implementation of Waveform.translate that does not call render"
  TChangeBits{} -> errorX "translator not supported"
  TAdvancedSum{} -> errorX "translator not supported"
  TAdvancedProduct{} -> errorX "translator not supported"

  -- normal
  TSum _ -> case subs of
    [(_,t)] -> t
    _ -> errorT "{invalid variant}"
  TProduct
    { start, sep, stop
    , labels
    , preci, preco
    } -> Translation (Just (v,WSDefault,preco)) $ filterSignals subs
      where
        labels' = L.map Just labels <> L.repeat Nothing
        subs' = applyPrecs preci subs
        vals = L.map (getVal . snd) subs'
        v = start <> joinWith sep fields <> stop
        fields = L.zipWith addLabel labels' vals
        addLabel = \case
          Just l -> (l<>)
          Nothing -> id
  TConst t -> t
  TArray
    { len
    , start, sep, stop
    , preci, preco
    } -> Translation ren subs
      where
        ren = if L.length subs == len then
          Just
            (    start
              <> joinWith sep (L.map (getVal . applyPrec preci . snd) subs)
              <> stop
            , WSDefault, preco )
        else
          errorR "{values missing}"

  -- recursive
  TStyled sty t -> applyStyle sty $ translateFromSubs t subs
  TDuplicate n t -> Translation ren [(n,t')]
    where t' = translateFromSubs t subs
          Translation ren _ = t'



-- | Translate a 'BitList' using the provided translator.
translateBinT :: Translator -> BitList -> Translation
translateBinT trans@(Translator width variant) bin''@(BL _ _ blLength)
  | width <= blLength, bin <- BL.take width bin'' = case variant of
    TRef _ TypeRef{translateBinRef} -> translateBinRef bin
    TLut _ TypeRef{translateBinRef} -> translateBinRef bin
    TNumber{format,spacer} -> Translation (if isJust render then render else Just ("undefined",WSError,11) ) []
      where
        bin' = show bin
        render :: Render
        render = (\((pref,v),s,p) -> (pref <> applySpacer spacer v,s,p)) <$> case format of
          NFBin -> Just (("0b",bin')                                  , undefStyle, 11)
          NFOct -> Just (("0o",hexDigit <$> chunksOf 3 (extendBits 3)), undefStyle, 11)
          NFHex -> Just (("0X",hexDigit <$> chunksOf 4 (extendBits 4)), undefStyle, 11)
          NFUns -> (\i -> (("",show i), WSDefault, 11))                     <$> decodeUns 0 bin'
          NFSig -> (\i -> (("",show i), WSDefault, if i>=0 then 11 else 0)) <$> decodeSig bin'

        undefStyle = if 'x' `elem` bin' then WSError else WSDefault
        extendBits k = L.replicate (k-1 - ((width+k-1) `rem` k)) '0' <> bin'

        hexDigit :: String -> Char
        hexDigit b = fromMaybe 'x' (((`showHex` "") <$> decodeUns 0 b :: Maybe String) >>= ((fst <$>) . L.uncons))

    -- normal
    TSum subs -> translation
      where
        k = intLog2 $ L.length subs * 2 - 1
        (b,b') = BL.split k bin
        translation = maybe
          (errorT "undefined")
          (\v -> translateBinT (subs L.!! fromIntegral v) b') --translate with selected translator
          (BL.toInteger b)

    TAdvancedSum{index,defTrans,rangeTrans} -> case BL.toInteger $ BL.slice index bin of
      Just i -> translateBinT t bin
        where
          t = fromMaybe defTrans $ asum $ L.map go rangeTrans
          go ((a,b),t') | a<=i && i<b = Just t'
                        | otherwise = Nothing
      Nothing -> errorT "undefined"

    TProduct{ subs }
      -> translateFromSubs trans subTs
      where
        subTs = carryFoldl go bin subs
        go b (lbl,t@(Translator w _)) = let (b',b'') = BL.split w b in (b'',(lbl,translateBinT t b'))

    TConst t -> t

    TArray{ sub=sub@(Translator w _), len}
      -> translateFromSubs trans subTs
      where
        subTs = enumLabel $ L.map (("",) . translateBinT sub) $ carryFoldl go bin [0..len-1]
        go b _ = let (b',b'') = BL.split w b in (b'',b')

    TAdvancedProduct{sliceTrans,hierarchy,valueParts,preco} -> Translation ren subs
      where
        translations = L.map (\(s,translator) -> translateBinT translator $ BL.slice s bin) sliceTrans
        ren = Just (L.concatMap getValPart valueParts, WSDefault, preco)
        subs = L.map (second (translations L.!!)) hierarchy

        getValPart (VPLit s) = s
        getValPart (VPRef i p) = getVal $ applyPrec p $ translations L.!! i

    -- recursive
    TStyled sty t -> applyStyle sty $ translateBinT t bin
    TDuplicate n t -> Translation ren' [(n,t')]
      where t' = translateBinT t bin
            Translation ren _ = t'
            ren' = (\(v,_,p) -> (v,WSInherit 0,p)) <$> ren

    TChangeBits{sub,bits} -> translateBinT sub $ changeBits bits bin
  | otherwise = errorX $ "BitList length ("<>show blLength<>") is smaller than translator length ("<>show width<>")"


-- structure

-- | Return the 't:Structure' implied by a 't:Translator'. Useful for determining
-- the structure of a constant translation.
structureT :: Translator -> Structure
structureT (Translator _ t) = case t of
  TRef _ TypeRef{structureRef} -> structureRef
  TSum ts -> Structure subs
    where subs = L.concatMap (getS . structureT) ts
          getS (Structure s) = s
  TAdvancedSum{rangeTrans,defTrans} -> structureT $ Translator 0 $ TSum (defTrans : L.map snd rangeTrans)
  TProduct{subs} -> Structure  $ L.map (second structureT) subs
  TConst trans -> fromTranslation trans
  TLut _ TypeRef{structureRef} -> structureRef
  TNumber{} -> Structure []
  TArray{sub,len} ->
      Structure . L.map (first show) . enumerate
    $ L.replicate len $ structureT sub
   where enumerate = L.zip [(0::Int)..]
  TAdvancedProduct{sliceTrans,hierarchy} -> Structure $ L.map (second (structures L.!!)) hierarchy
    where structures = L.map (structureT . snd) sliceTrans
  TStyled _ t' -> structureT t'
  TDuplicate n t' -> Structure [(n,structureT t')]
  TChangeBits{sub} -> structureT sub

-- | Construct a 't:Structure' from a 't:Translation'.
fromTranslation :: Translation -> Structure
fromTranslation (Translation _ subs) = Structure $ L.map (second fromTranslation) subs


-- translator based functions

{- FOURMOLU_DISABLE -}
-- | Run a function on a translator's subtranslators, and combine the results.
-- This follows 'TRef' references.
foldTranslator :: (Translator -> a) -> ([a] -> b) -> Translator -> b
foldTranslator m f (Translator _ variant) = case variant of
  -- leaf translators
  TRef _ TypeRef{translatorRef}     -> f [m translatorRef]
  TLut _ _                          -> f []
  TConst _                          -> f []
  TNumber{}                         -> f []

  -- combining
  TSum subs                         -> f $ L.map m subs
  TAdvancedSum{defTrans,rangeTrans} -> f $ L.map (m . snd) rangeTrans <> [m defTrans]
  TProduct{subs}                    -> f $ L.map (m . snd) subs
  TArray{sub}                       -> f [m sub]
  TAdvancedProduct{sliceTrans}      -> f $ L.map (m . snd) sliceTrans

  -- single recursive
  TStyled _ t                       -> f [m t]
  TDuplicate _ t                    -> f [m t]
  TChangeBits{sub}                  -> f [m sub]
{- FOURMOLU_ENABLE -}

-- | Test if there is a LUT translator in a translator (following references).
hasLutT :: Translator -> Bool
hasLutT (Translator _ (TLut _ _)) = True
hasLutT t = foldTranslator hasLutT or t

-- | Add all type references in a translator structure to a type map.
-- To add the types in a type, run this function on a reference to said type.
addTypesT :: Translator -> (TypeMap -> TypeMap)
addTypesT t | Translator _ (TRef n TypeRef{translatorRef}) <- t = addType n translatorRef . addSubTypes
            | otherwise                                         = addSubTypes
  where
    addSubTypes = foldTranslator addTypesT (L.foldl (.) id) t





-- lut stuff

-- | From a translator, create a function that given a binary value
-- returns a list of functions to add all LUT values to the LUT maps.
addValueT :: Translator -> BitList -> [LUTMap -> LUTMap]
addValueT translator@(Translator _ variant) = if hasLutT translator then
  case variant of
    -- leaf translators
    TRef _ TypeRef{translatorRef} -> addValueT translatorRef
    TLut name TypeRef{translateBinRef} -> go
      where
        go bin =
          let translation = safeValOr (errorT "error") (translateBinRef bin)
          in [M.alter (Just . insertIfMissing bin translation . fromMaybe M.empty) name]
    TConst _ -> const []
    TNumber{} -> const []

    -- combining
    TSum subs -> go
      where
        fSubs = L.map addValueT subs
        k = intLog2 $ L.length subs * 2 - 1
        go bl =
          let (b',b'') = BL.split k bl
          in case BL.toInteger b' of
              Just i -> (fSubs L.!! fromIntegral i) b''
              Nothing -> []

    TAdvancedSum{index,defTrans,rangeTrans} -> go
      where
        fDefTrans = addValueT defTrans
        fRangeTrans = L.map (second addValueT) rangeTrans
        go bin = case BL.toInteger $ BL.slice index bin of
          Just i -> fs bin
            where
              fs = fromMaybe fDefTrans $ asum $ L.map go' fRangeTrans
              go' ((a,b),f) | a<=i && i<b = Just f
                            | otherwise = Nothing
          Nothing -> []

    TProduct{subs} -> go'
      where
        fSubs = L.map (\(_,trans@(Translator w _)) -> (w,addValueT trans)) subs
        go' bin = L.concat $ carryFoldl go bin fSubs
        go b (w,f) = let (b',b'') = BL.split w b in (b'',f b')

    TArray{sub=sub@(Translator w _),len} -> go'
      where
        fSub = addValueT sub
        go' bin = L.concat $ carryFoldl go bin [0..len-1]
        go b _ = let (b',b'') = BL.split w b in (b'',fSub b')

    TAdvancedProduct{sliceTrans} -> go
      where
        fSliceTrans = L.map (second addValueT) sliceTrans
        go bin = L.concatMap (\(s,f) -> f $ BL.slice s bin) fSliceTrans

    -- single recursive
    TStyled _ t -> addValueT t
    TDuplicate _ t -> addValueT t
    TChangeBits{sub,bits} -> go
      where
        fSub = addValueT sub
        go bin = fSub $ changeBits bits bin
  else const []
