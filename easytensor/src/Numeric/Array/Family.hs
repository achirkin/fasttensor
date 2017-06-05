
{-# LANGUAGE DataKinds, PolyKinds, TypeFamilyDependencies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE FlexibleContexts, FlexibleInstances #-}
{-# LANGUAGE TypeOperators    #-}
{-# LANGUAGE UnboxedTuples, MagicHash #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ExistentialQuantification  #-}
-- {-# LANGUAGE TypeApplications  #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Numeric.Array.Family
-- Copyright   :  (c) Artem Chirkin
-- License     :  MIT
--
-- Maintainer  :  chirkin@arch.ethz.ch
--
--
-----------------------------------------------------------------------------

module Numeric.Array.Family
  ( ArrayType
  -- , VectorType
  -- , MatrixType
  , ArrayF (..)
  , Scalar (..)
  , ArrayInstanceInference (..)
  ) where

import GHC.TypeLits (Nat)
import GHC.Prim
import Numeric.Commons
import Numeric.Dimensions
-- import Numeric.Vector.Family

-- -- | Simplified synonym for an array of order 1
-- type VectorType t (n :: Nat) = ArrayType t '[n]
-- -- | Simplified synonym for an array of order 2
-- type MatrixType t (n :: Nat) (m :: Nat) = ArrayType t '[n,m]

-- | Full collection of n-order arrays
type family ArrayType t (ds :: [Nat]) = v | v -> t ds where
  ArrayType t     '[]  = Scalar t
  -- ArrayType Float '[2] = VFloatX2
  ArrayType Float (d ': ds)    = ArrayF (d ': ds)


-- | Specialize scalar type without any arrays
newtype Scalar t = Scalar { _unScalar :: t }
  deriving ( Bounded, Enum, Eq, Integral
           , Num, Fractional, Floating, Ord, Read, Real, RealFrac, RealFloat
           , PrimBytes, FloatBytes, DoubleBytes, IntBytes, WordBytes)
instance Show t => Show (Scalar t) where
  show (Scalar t) = "{ " ++ show t ++ " }"
type instance ElemRep (Scalar t) = ElemRep t

-- | Indexing over scalars is trivial...
instance ElementWise (Idx ('[] :: [Nat])) t (Scalar t) where
  (!) x _ = _unScalar x
  {-# INLINE (!) #-}
  ewmap f = Scalar . f Z . _unScalar
  {-# INLINE ewmap #-}
  ewgen f = Scalar $ f Z
  {-# INLINE ewgen #-}
  ewfold f x0 x = f Z (_unScalar x) x0
  {-# INLINE ewfold #-}
  elementWise f = fmap Scalar . f . _unScalar
  {-# INLINE elementWise #-}
  indexWise f = fmap Scalar . f Z . _unScalar
  {-# INLINE indexWise #-}
  broadcast = Scalar
  {-# INLINE broadcast #-}

-- * Array implementations.
--   All array implementations have the same structure:
--   Array[Type] (element offset :: Int#) (element length :: Int#)
--                 (content :: ByteArray#)
--   All types can also be instantiated with only a single scalar.

-- | N-Dimensional arrays based on Float# type
data ArrayF (ds :: [Nat]) = ArrayF# Int# Int# ByteArray#
                          | FromScalarF# Float#


-- | Keep information about the instance behind ArrayType family
data ArrayInstance t (ds :: [Nat])
  = ArrayType t ds ~ Scalar t => AIScalar
  | ArrayType t ds ~ ArrayF ds => AIArrayF

-- | Use this typeclass constraint in libraries functions if there is a need
--   to select an instance of ArrayType famility at runtime.
class ArrayInstanceInference t ds where
  -- | Get the actual instance of an array behind the type family.
  --   Use TypeApplications extension:
  --   e.g. pattern matching on `inferArrayInstance @Int @'[]` produces evidence
  --        that `ArrayType Int '[] ~ Scalar Int`
  inferArrayInstance :: ArrayInstance t ds


instance ArrayInstanceInference t '[] where
  inferArrayInstance = AIScalar

instance ArrayInstanceInference Float (d ': ds) where
  inferArrayInstance = AIArrayF




_suppressHlintUnboxedTuplesWarning :: () -> (# (), () #)
_suppressHlintUnboxedTuplesWarning = undefined
