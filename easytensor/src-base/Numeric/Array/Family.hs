{-# LANGUAGE CPP                        #-}
{-# LANGUAGE ConstraintKinds            #-}
{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE ExistentialQuantification  #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MagicHash                  #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE StandaloneDeriving         #-}
{-# LANGUAGE TypeApplications           #-}
{-# LANGUAGE TypeFamilies               #-}
{-# LANGUAGE TypeFamilyDependencies     #-}
{-# LANGUAGE TypeInType                 #-}
{-# LANGUAGE TypeOperators              #-}
{-# LANGUAGE Rank2Types              #-}
{-# LANGUAGE PolyKinds              #-}
{-# LANGUAGE UnboxedTuples              #-}
{-# LANGUAGE UnboxedSums              #-}
{-# LANGUAGE GADTs              #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Numeric.DataFrame.Internal.Array.Family
-- Copyright   :  (c) Artem Chirkin
-- License     :  BSD3
--
-- Maintainer  :  chirkin@arch.ethz.ch
--
--
-----------------------------------------------------------------------------

module Numeric.DataFrame.Internal.Array.Family
  ( Array, Scalar (..), ArrayBase (..)
  --  Array
  -- , ArrayF (..), ArrayD (..)
  -- , ArrayI (..), ArrayI8 (..), ArrayI16 (..), ArrayI32 (..), ArrayI64 (..)
  -- , ArrayW (..), ArrayW8 (..), ArrayW16 (..), ArrayW32 (..), ArrayW64 (..)
  -- , Scalar (..)
  -- , FloatX2 (..), FloatX3 (..), FloatX4 (..)
  -- , DoubleX2 (..), DoubleX3 (..), DoubleX4 (..)
  -- , ArrayInstanceInference, ElemType (..), ArraySize (..)
  -- , ElemTypeInference (..), ArraySizeInference (..), ArrayInstanceEvidence
  -- , getArrayInstance, ArrayInstance (..), inferArrayInstance
  ) where

#include "MachDeps.h"

import           Data.Proxy
-- import           Data.Int                  (Int16, Int32, Int64, Int8)
import           Data.Type.Equality        ((:~:) (..))
-- import           Data.Word                 (Word16, Word32, Word64, Word8)
import           GHC.Exts                  -- (RuntimeRep (..))
import           GHC.Base                  hiding (foldr)
-- (ByteArray#, Double#, Float#, Int#
                                           --,Word#, unsafeCoerce#
-- #if WORD_SIZE_IN_BITS < 64
--                                            ,Int64#, Word64#
-- #endif
                                        --   )

-- import           Numeric.DataFrame.Internal.Array.ElementWise
-- import           Numeric.Commons
import           Numeric.Dimensions
import Numeric.DataFrame.Internal.Array.Family.ArrayBase

-- | This type family aggregates all types used for arrays with different
--   dimensioinality.
--   The family is injective; thus, it is possible to get type family instance
--   given the data constructor (and vice versa).
--   If GHC knows the dimensionality of an array at compile time, it chooses
--   a more efficient specialized instance of Array, e.g. Scalar newtype wrapper.
--   Otherwise, it falls back to the generic ArrayBase implementation.
--
--   Data family would not work here, because it would give overlapping instances.
--
--   We have two types of dimension lists here: @[Nat]@ and @[XNat]@.
--   Thus, all types are indexed by the kind of the Dims, either @Nat@ or @XNat@.
type family Array k (t :: Type) (ds :: [k]) = v | v -> t ds k where
    Array k    t      '[]    = Scalar k t
    Array Nat  Float  '[2]   = FloatX2 Nat
    Array Nat  Float  '[3]   = FloatX3 Nat
    Array Nat  Float  '[4]   = FloatX4 Nat
    Array Nat  Double '[2]   = DoubleX2 Nat
    Array Nat  Double '[3]   = DoubleX3 Nat
    Array Nat  Double '[4]   = DoubleX4 Nat
    Array XNat Float  '[N 2] = FloatX2 XNat
    Array XNat Float  '[N 3] = FloatX3 XNat
    Array XNat Float  '[N 4] = FloatX4 XNat
    Array XNat Double '[N 2] = DoubleX2 XNat
    Array XNat Double '[N 3] = DoubleX3 XNat
    Array XNat Double '[N 4] = DoubleX4 XNat
    Array k    t       ds    = ArrayBase k t ds

-- | A framework for using Array type family instances.
class ArraySingleton k t (ds :: [k]) where
    -- | Get Array type family instance
    aSing :: ArraySing k t ds

data ArraySing k t (ds :: [k]) where
    AScalar :: (Array k t ds ~ Scalar k t)       => ArraySing k t     '[]
    AF2     :: (Array k t ds ~ FloatX2 k)        => ArraySing k Float  ds
    AF3     :: (Array k t ds ~ FloatX3 k)        => ArraySing k Float  ds
    AF4     :: (Array k t ds ~ FloatX4 k)        => ArraySing k Float  ds
    AD2     :: (Array k t ds ~ DoubleX2 k)       => ArraySing k Double ds
    AD3     :: (Array k t ds ~ DoubleX3 k)       => ArraySing k Double ds
    AD4     :: (Array k t ds ~ DoubleX4 k)       => ArraySing k Double ds
    ABase   :: (Array k t ds ~ ArrayBase k t ds) => ArraySing k t      ds

deriving instance Eq (ArraySing k t ds)
deriving instance Ord (ArraySing k t ds)
deriving instance Show (ArraySing k t ds)



-- | This function does GHC's magic to convert user-supplied `aSing` function
--   to create an instance of `ArraySingleton` typeclass at runtime.
--   The trick is taken from Edward Kmett's reflection library explained
--   in https://www.schoolofhaskell.com/user/thoughtpolice/using-reflection
reifyArraySing :: forall r k t ds
                . ArraySing k t ds -> ( ArraySingleton k t ds => r) -> r
reifyArraySing as k
  = unsafeCoerce# (MagicArraySing k :: MagicArraySing k t ds r) as
{-# INLINE reifyArraySing #-}
newtype MagicArraySing k t (ds :: [k]) r
  = MagicArraySing (ArraySingleton k t ds => r)

aSingEv :: ArraySing k t ds -> Evidence (ArraySingleton k t ds)
aSingEv ds = reifyArraySing ds E
{-# INLINE aSingEv #-}



instance {-# OVERLAPPABLE #-} ArraySingleton k t (ds :: [k])    where
    aSing = unsafeCoerce# (ABase :: ArraySing XNat t '[XN 0])
instance {-# OVERLAPPING #-}  ArraySingleton k    t      '[]    where
    aSing = AScalar
instance {-# OVERLAPPING #-}  ArraySingleton Nat  Float  '[2]   where
    aSing = AF2
instance {-# OVERLAPPING #-}  ArraySingleton Nat  Float  '[3]   where
    aSing = AF3
instance {-# OVERLAPPING #-}  ArraySingleton Nat  Float  '[4]   where
    aSing = AF4
instance {-# OVERLAPPING #-}  ArraySingleton XNat Float  '[N 2] where
    aSing = AF2
instance {-# OVERLAPPING #-}  ArraySingleton XNat Float  '[N 3] where
    aSing = AF3
instance {-# OVERLAPPING #-}  ArraySingleton XNat Float  '[N 4] where
    aSing = AF4
instance {-# OVERLAPPING #-}  ArraySingleton Nat  Double '[2]   where
    aSing = AD2
instance {-# OVERLAPPING #-}  ArraySingleton Nat  Double '[3]   where
    aSing = AD3
instance {-# OVERLAPPING #-}  ArraySingleton Nat  Double '[4]   where
    aSing = AD4
instance {-# OVERLAPPING #-}  ArraySingleton XNat Double '[N 2] where
    aSing = AD2
instance {-# OVERLAPPING #-}  ArraySingleton XNat Double '[N 3] where
    aSing = AD3
instance {-# OVERLAPPING #-}  ArraySingleton XNat Double '[N 4] where
    aSing = AD4







-- | Specialize scalar type without any arrays
newtype Scalar k t = Scalar { _unScalar :: t }
  deriving ( Enum, Eq, Integral
           , Num, Fractional, Floating, Ord, Read, Real, RealFrac, RealFloat)
instance Show t => Show (Scalar k t) where
  show (Scalar t) = "{ " ++ show t ++ " }"

deriving instance {-# OVERLAPPABLE #-} Bounded t => Bounded (Scalar k t)
instance {-# OVERLAPPING #-} Bounded (Scalar k Double) where
  maxBound = Scalar inftyD
  minBound = Scalar $ negate inftyD
instance {-# OVERLAPPING #-} Bounded (Scalar k Float) where
  maxBound = Scalar inftyF
  minBound = Scalar $ negate inftyF
inftyD :: Double
inftyD = read "Infinity"
inftyF :: Float
inftyF = read "Infinity"



-- * Specialized types
--   More efficient data types for small fixed-size tensors
data FloatX2 k = FloatX2# Float# Float#
data FloatX3 k = FloatX3# Float# Float# Float#
data FloatX4 k = FloatX4# Float# Float# Float# Float#

data DoubleX2 k = DoubleX2# Double# Double#
data DoubleX3 k = DoubleX3# Double# Double# Double#
data DoubleX4 k = DoubleX4# Double# Double# Double# Double#
