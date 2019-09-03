{-# LANGUAGE DataKinds           #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE GADTs               #-}
{-# LANGUAGE PolyKinds           #-}
{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell     #-}
{-# LANGUAGE TypeApplications    #-}
{-# LANGUAGE TypeOperators       #-}

module Numeric.Matrix.BidiagonalTest (runTests) where


import Control.Monad                 (join)
import Data.Kind
import Data.List                     (inits, tails)
import Data.Monoid                   (All (..))
import Numeric.DataFrame
import Numeric.DataFrame.Arbitraries ()
import Numeric.Dimensions
import Numeric.Matrix.Bidiagonal
import Test.QuickCheck

eps :: Fractional t => Scalar t
eps = 1.0e-13

-- check invariants of SVD
validateBidiagonal :: forall (t :: Type) (n :: Nat) (m :: Nat)
             . ( KnownDim n, KnownDim m, KnownDim (Min n m)
               , PrimBytes t, Floating t, Ord t, Show t
               )
            => Matrix t n m -> (Matrix t n n, Matrix t n m, Matrix t m m) -> Property
validateBidiagonal a (u, b, v)
  | Dict <- inferKnownBackend @_ @t @'[Min n m]
  , Dict <- inferKnownBackend @_ @t @'[m] =
    counterexample
      (unlines
        [ "failed a ~==~ u %* b %* transpose v:"
        , "a:  " ++ show a
        , "a': " ++ show a'
        , "u:"   ++ show u
        , "b:"   ++ show b
        , "v:"   ++ show v
        ]
      ) (approxEq a a')
    .&&.
    counterexample
      (unlines
        [ "u is not quite orthogonal:"
        , "a:  " ++ show a
        , "u:"   ++ show u
        , "b:"   ++ show b
        , "v:"   ++ show v
        ]
      ) (approxEq eye $ u %* transpose u)
    .&&.
    counterexample
      (unlines
        [ "v is not quite orthogonal:"
        , "a:  " ++ show a
        , "u:"   ++ show u
        , "b:"   ++ show b
        , "v:"   ++ show v
        ]
      ) (approxEq eye $ v %* transpose v)
    .&&.
    counterexample
      (unlines
        [ "b is not upper-bidiagonal"
        , "a:  " ++ show a
        , "u:"   ++ show u
        , "b:"   ++ show b
        , "v:"   ++ show v
        ]
      ) (getAll $ iwfoldMap @t @'[n,m]
            (\(Idx i :* Idx j :* U) x -> All (j == i || j == i + 1 || x == 0))
            b
        )
  where
    a'  = u %* b %* transpose v


-- | Most of the time, the error is proportional to the maginutude of the biggest element
maxElem :: (SubSpace t ds '[] ds, Ord t, Num t)
        => DataFrame t (ds :: [Nat]) -> Scalar t
maxElem = ewfoldl (\a -> max a . abs) 0

rotateList :: [a] -> [[a]]
rotateList xs = init (zipWith (++) (tails xs) (inits xs))

approxEq ::
  forall t (ds :: [Nat]) .
  (
    Dimensions ds,
    Fractional t, Ord t, Show t,
    Num (DataFrame t ds),
    PrimBytes (DataFrame t ds),
    PrimArray t (DataFrame t ds)
  ) => DataFrame t ds -> DataFrame t ds -> Property
approxEq a b = counterexample
    (unlines
      [ "  approxEq failed:"
      , "    max rows: "   ++ show m
      , "    max diff: "   ++ show dif
      ]
    ) $ maxElem (a - b) <= eps * m
  where
    m = maxElem a `max` maxElem b
    dif = maxElem (a - b)
infix 4 `approxEq`


prop_bidiagonalSimple :: Property
prop_bidiagonalSimple = once . conjoin $ map prop_bidiagonal $ xs
  where
    mkM :: Dims ([n,m]) -> [Double] -> DataFrame Double '[XN 1, XN 1]
    mkM ds
      | Just (XDims ds') <- constrainDims ds :: Maybe (Dims '[XN 1, XN 1])
        = XFrame . fromFlatList ds' 0
    mkM _ = error "prop_qrSimple: bad dims"
    variants :: Num a => [a] -> [[a]]
    variants as = rotateList as ++ rotateList (map negate as)
    xs :: [DataFrame Double '[XN 1, XN 1]]
    xs = join
      [ [mkM $ D2 :* D2 :* U, mkM $ D5 :* D2 :* U, mkM $ D3 :* D7 :* U]
            <*> [repeat 0, repeat 1, repeat 2]
      , mkM (D2 :* D2 :* U) <$> variants [3,2, 4,1]
      , mkM (D3 :* D3 :* U) <$> variants [0,0,1, 3,2,0, 4,1,0]
      , mkM (D4 :* D2 :* U) <$> variants [3,2, 4,1, 0,0, 0,2]
      , mkM (D2 :* D3 :* U) <$> variants [3,2,0, 4,1,2]
      , mkM (D2 :* D2 :* U) <$> variants [2, 0, 0, 0]
      , mkM (D2 :* D2 :* U) <$> variants [4, 1, 0, 0]
      , mkM (D2 :* D2 :* U) <$> variants [3, 1, -2, 0]
      , [mkM $ D2 :* D3 :* U, mkM $ D3 :* D2 :* U]
            <*> join
                [ variants [2, 0, 0, 0, 0, 0]
                , variants [4, 1, 0, 0, 0, 0]
                , variants [3, 1, -2, 0, 0, 0]
                , variants [3, 0, -2, 9, 0, 0]
                ]
      ]

prop_bidiagonal :: DataFrame Double '[XN 1, XN 1] -> Property
prop_bidiagonal (XFrame x)
  | n@D :* m@D :* U <- dims `inSpaceOf` x
  , D <- minDim n m
    = validateBidiagonal x (bidiagonalHouseholder x)
prop_bidiagonal _ = property False




return []
runTests :: Int -> IO Bool
runTests n = $forAllProperties
  $ quickCheckWithResult stdArgs { maxSuccess = n }