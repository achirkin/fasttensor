-----------------------------------------------------------------------------
-- |
-- Module      :  Numeric.DataFrame.BasicTest
-- Copyright   :  (c) Artem Chirkin
-- License     :  MIT
--
-- Maintainer  :  chirkin@arch.ethz.ch
--
-- A set of basic validity tests for DataFrame type.
-- Num, Ord, Fractional, Floating, etc
--
-----------------------------------------------------------------------------
{-# LANGUAGE DataKinds            #-}
{-# LANGUAGE KindSignatures       #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE FlexibleContexts     #-}
{-# LANGUAGE TypeApplications     #-}
{-# LANGUAGE Rank2Types           #-}
{-# LANGUAGE ConstraintKinds      #-}
{-# LANGUAGE TypeOperators        #-}
{-# LANGUAGE GADTs                #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# LANGUAGE PolyKinds #-}

module Numeric.DataFrame.Arbitraries where

import           GHC.TypeLits
import           Test.QuickCheck
import           Data.Type.Equality
--import           Data.Proxy
import           Unsafe.Coerce


import           Numeric.DataFrame
import           Numeric.Dimensions



maxDims :: Int
maxDims = 5

maxDimSize :: Int
maxDimSize = 7

-- | Fool typechecker by saying that a ~ b
unsafeEqProof :: forall (a :: k) (b :: k) . a :~: b
unsafeEqProof = unsafeCoerce Refl



-- | Generating random DataFrames
newtype SimpleDF (ds :: [Nat] ) = SDF { getDF :: DataFrame Float ds}
data SomeSimpleDF = forall (ds :: [Nat])
                  . (Dimensions ds, FPDataFrame Float ds)
                 => SSDF !(SimpleDF ds)
data SomeSimpleDFNonScalar
    = forall (ds :: [Nat]) (a :: Nat) (z :: Nat) (as :: [Nat]) (zs :: [Nat])
    . ( Dimensions ds
      , FPDataFrame Float ds
      , ds ~ (a :+ as), ds ~ (zs +: z)
      )
   => SSDFN !(SimpleDF ds)
data SomeSimpleDFPair = forall (ds :: [Nat])
                      . ( Dimensions ds
                        , FPDataFrame Float ds
                        )
                     => SSDFP !(SimpleDF ds) !(SimpleDF ds)

instance ( Dimensions ds
         , FPDataFrame Float ds
         ) => Arbitrary (SimpleDF (ds :: [Nat])) where
  arbitrary = SDF <$> elementWise (dim @ds) f 0
    where
      f :: Scalar Float -> Gen (Scalar Float)
      f _ = scalar <$> choose (-10000,100000)
  shrink sdf = SDF <$> elementWise (dim @ds) f (getDF sdf)
    where
      f :: Scalar Float -> [Scalar Float]
      f = fmap scalar . shrink . unScalar


instance Arbitrary SomeSimpleDF where
  arbitrary = do
    dimN <- choose (0, maxDims) :: Gen Int
    dims <- mapM (\_ -> choose (2, maxDimSize) :: Gen Int) [1..dimN]
    let eGen = withRuntimeDim dims $
          \(_ :: Dim ds) -> inferFloating (undefined :: DataFrame Float ds) $
            \_ -> case ( unsafeEqProof :: (2 <=? Head ds) :~: 'True
                       ) of
              Refl -> SSDF <$> (arbitrary :: Gen (SimpleDF ds))
    case eGen of
      Left s -> error $ "Cannot generate arbitrary SomeSimpleDF: " ++ s
      Right v -> v
  shrink (SSDF x) = SSDF <$> shrink x


instance Arbitrary SomeSimpleDFNonScalar where
  arbitrary = do
    dimN <- choose (1, maxDims) :: Gen Int
    dims <- mapM (\_ -> choose (2, maxDimSize) :: Gen Int) [1..dimN]
    let eGen = withRuntimeDim dims $
          \(_ :: Dim ds) -> inferFloating (undefined :: DataFrame Float ds) $
            \_ -> case ( unsafeEqProof :: ds :~: (Head ds :+ Tail ds)
                       , unsafeEqProof :: ds :~: (Init ds +: Last ds)
                       ) of
              (Refl, Refl) -> SSDFN <$> (arbitrary :: Gen (SimpleDF ds))
    case eGen of
      Left s -> error $ "Cannot generate arbitrary SomeSimpleDF: " ++ s
      Right v -> v
  shrink (SSDFN x) = SSDFN <$> shrink x


instance Arbitrary SomeSimpleDFPair where
  arbitrary = do
    dimN <- choose (0, maxDims) :: Gen Int
    dims <- mapM (\_ -> choose (2, maxDimSize) :: Gen Int) [1..dimN]
    let eGen = withRuntimeDim dims $
          \(_ :: Dim ds) -> inferFloating (undefined :: DataFrame Float ds) $
            \_ -> SSDFP <$> (arbitrary :: Gen (SimpleDF ds)) <*> (arbitrary :: Gen (SimpleDF ds))
    case eGen of
      Left s -> error $ "Cannot generate arbitrary SomeSimpleDF: " ++ s
      Right v -> v
  shrink (SSDFP x y) = SSDFP <$> shrink x <*> shrink y

instance Show (DataFrame Float ds) => Show (SimpleDF ds) where
  show (SDF sdf) = show sdf
instance Show SomeSimpleDF where
  show (SSDF sdf) = show sdf
instance Show SomeSimpleDFNonScalar where
  show (SSDFN sdf) = show sdf
instance Show SomeSimpleDFPair where
  show (SSDFP x y) = "Pair:\n" ++ show (x,y)