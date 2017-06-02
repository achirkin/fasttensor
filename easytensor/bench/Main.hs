
{-# LANGUAGE DataKinds, KindSignatures #-}
{-# LANGUAGE GADTs     #-}
{-# LANGUAGE TypeApplications      #-}
{-# LANGUAGE ScopedTypeVariables      #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeOperators #-}
-- {-# LANGUAGE IncoherentInstances #-}
{-# LANGUAGE MagicHash                  #-}

module Main (main) where

import Data.Proxy
import GHC.TypeLits
import GHC.Types
-- import           GHC.Exts
--import Numeric.Tensor (Dim(..))
-- import           Numeric.Commons
-- import qualified Numeric.Tensor     as T
-- import Numeric.Vector ((<:>))
-- import qualified Numeric.Vector as V
-- import qualified Numeric.Matrix as M
-- import           Numeric.EasyTensor

-- import           Foreign.Marshal
-- import           Foreign.Ptr
-- import           Foreign.Storable
-- import Data.Type.Equality
import Numeric.Dimensions
import Numeric.DataFrame
import Numeric.Commons (ix)
-- import Unsafe.Coerce
import Data.Functor.Identity
import Data.Functor.Const
import Data.Semigroup

main :: IO ()
main = do
    print $ F# (ix 0# (3 :: Float))
    putStrLn "Hello world!"
--     print (Proxy @3 :* Proxy @2 :* (D :: Dim ('[] :: [Nat])))
--     print $ case (,,,)  <$> someNatVal 3
--                         <*> someNatVal 6
--                         <*> someNatVal 8
--                         <*> someNatVal 4
--                         of
--       Nothing -> Nothing
--       Just (a,b,c,d) -> xDimVal $ a :? b :? c :? d :? D
--     putStrLn s
--     putStrLn s2
--     -- look at this hole: amazing type inference!
--     -- putStrLn $ _ x3
--     putStrLn x3
--     print dfY
-- --    putStrLn $ _ %* mat22 (vec2 1 0) (vec2 0 2)
-- --    putStrLn $ vec2 2 (3 :: Float) %* _
--     print $ vec2 2 (3 :: Float) %* mat22 (vec2 1 0) (vec2 0 2)
--     print $ vec2 2 3 %* matX
--     print $ vec2 2 3 %* transpose matX
--     print $ matX %* transpose matX
--     print $ det matX
--     print $ inverse matX
--     -- print dfY2
--     print $ runSlice (subSpace (\_ mat -> Const (Sum mat) :: Const (Sum (DataFrame Float '[3, 2])) Scf)) ixs
--     print $ runSlice (slice (Get 1 :& 3) pleaseFire) ixs
--     print $ runSlice (slice (Get 1 :& 3 :& 4) (const $ Identity . (* 0.7))) ixs
--     print dimVec2
--     print sVec2
--     print $ index 2 (Identity . (+0.5)) ixs
--     print $ index 3 Const ixs
--     print ixs
--     print $ index 3 Const ixs -- xx.yy.3
--     print $  (index 3 . index 1) Const ixs -- xx.1.3
--     print $  (index 3 . index 1 . index 2) Const ixs -- 2.1.3
--     print $  (index 2 . index 2 . index 2) Const ixs -- 2.2.2
--     print $ totalDim ixs
--     print $ totalDim (Proxy @'[3,2])
--     print $ totalDim (Proxy @'[3])
--     print $ totalDim (Proxy @'[])
--     print $ ewmap (Proxy @4 :* D) (*0.5) ixs
--     print $ ewmap (Proxy @4 :* D) (%* vec2 2 (-1)) ixs
--     print $ ewfoldMap (Proxy @4 :* D) Sum ixs
--     print $ 3:!Z !. ixs
--     print $ 1:!3:!Z !. ixs
--     ---
--     putStrLn "\n\nTesting elementWise.\n ixs:\n"
--     print ixs
--     putStrLn "\n List traversable:\n"
--     print $ elementWise (dim @'[4]) (\x -> [x, x+0.375]) ixs
--     print $ case someDimVal [2,6,3] of
--       Just (SomeDim ds) -> show (dimMax `inSpaceOf` ds)
--       Nothing -> "Failed to get dim [2,6,3]"
--     print $ order (Proxy @'[3,2,3,4,6])
--     print $ case someDimVal [2,6,3] of
--       Just (SomeDim (_ :: Dim ds)) -> show (order (Proxy @(2 ': ds)))
--       Nothing -> "Failed to get dim [2,6,3]"
--     print $ dimMin @'[_,_] !. dfY
-- --    print $ subDimTest dfY Proxy
--     print $ case someNatVal 5 of
--               Nothing -> -1
--               Just (SomeNat p) -> case inferTakeNFiniteList p (Proxy @[2,8,1,7,34,8,12,7,12,2,7,9,0,12]) of
--                                     kle@FiniteListEvidence -> order kle
--     print $ case inferTakeNFiniteList (Proxy @6) (Proxy @[2,8,1,7,34,8,12,7,12,2,7,9,0,12]) of
--                                     kle@FiniteListEvidence -> order kle
--     -- case (,) <$> someNatVal 5 <*> someNatVal 7 of
--     --   Nothing -> print "Failed to do Test1"
--     --   Just (SomeNat p, SomeNat q) -> print
--     --     [funTest1v p q, funTest1v (Proxy @3) q, funTest1v p (Proxy @4), funTest1v (Proxy @1) (Proxy @2)]
--   where
--     pleaseFire :: Idx i -> DataFrame Float '[3, 2] -> Const (Sum (DataFrame Float '[3, 2])) Scf
--     pleaseFire _ = Const . Sum
--     ixs :: DataFrame Float '[3,2,4]
--     ixs = iwgen $ dim @'[3,2,4] `asSpaceOf` (\(i :! j :! k :! Z) -> scalar . realToFrac $ i*100 + j*10 + k)
--     matX = mat22 (vec2 0 2) (vec2 1 (0 :: Float))
--     Just d2 = someNatVal 2
--     Just d3 = someNatVal 5
--     dimX :: Dim '[N 3, XN, XN, N 2]
--     dimX = Proxy :* d2 :? d3 :? Proxy :* D
--     dimVec2 :: Dim '[XN]
--     dimVec2 = d2 :? D
--     sVec2 = case xDimVal dimVec2 of
--         Just (XDim ds) -> show (dfFloat 3.11 `inSpaceOf` ds)
--         Nothing -> "Failed to get xDimVal dimVec2"
--     s2 = case xDimVal dimVec2 of
--         Just (XDim ds) -> show (dfFloat (exp 3) `inSpaceOf` ds)
--         Nothing -> "Failed to get xDimVal dimVec2"
--     x3 = case xDimVal dimX of
--         Just (XDim ds) -> show $ unboundShape (dfFloat 42.0001 `inSpaceOf` ds) `inSpaceOf` Proxy @'[XN,XN,XN,N _]
--         Nothing -> "Failed to get xDimVal dimX"
--     s = case xDimVal dimX of
--         Just (XDim ds) -> let pix = 2 * dfFloat pi `inSpaceOf` ds
--                           in show pix ++ show (pix ! (1 :! 2 :! 1 :! 2 :! Z) :: Scf)
--         Nothing -> "Failed to get xDimVal dimX"
--     -- dimX1 :: Dim '[3,2,4]
--     -- dimX1 = dim
--     -- dimX2 :: Dim '[4,5,2]
--     -- dimX2 = dim
--     dfX1  :: DFF '[3,2,4]
--     dfX1  = pi
--     dfX2  :: DFF '[4,5]
--     dfX2  = 1
--     -- dfY :: DFF '[3,2,5]
--     dfY   = dfX1 %* dfX2
--
--     -- dfY2  = (runSlice . slice (Get 4 )
--     --                   $ slice (Get 2 :& 1 :& 1)
--     --                   (\(i :! j :! Z) v -> [ (v ! 1 :! Z) - realToFrac i
--     --                                        , (v ! 2 :! Z) *2 / realToFrac j])) dfY

dfFloat :: Fractional (DataFrame Float ds)
        => Float -> DataFrame Float (ds :: [Nat])
dfFloat = realToFrac


type DFF (ds :: [Nat]) = DataFrame Float ds