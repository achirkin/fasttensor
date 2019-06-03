{-# LANGUAGE AllowAmbiguousTypes        #-}
{-# LANGUAGE CPP                        #-}
{-# LANGUAGE ConstraintKinds            #-}
{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE DeriveDataTypeable         #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE ExistentialQuantification  #-}
{-# LANGUAGE ExplicitNamespaces         #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MagicHash                  #-}
{-# LANGUAGE PolyKinds                  #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE TypeApplications           #-}
{-# LANGUAGE UnboxedTuples              #-}
{-# LANGUAGE UndecidableInstances       #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Numeric.Dimensions.Idx
-- Copyright   :  (c) Artem Chirkin
-- License     :  BSD3
--
--
-- Provides a data type `Idx` to index `Dim` and `Idxs`
--   that enumerates through multiple dimensions.
--
-- Higher indices go first, i.e. assumed enumeration
--          is i = i1*n1*n2*...*n(k-1) + ... + i(k-2)*n1*n2 + i(k-1)*n1 + ik
-- This corresponds to row-first layout of matrices and multidimenional arrays.
--
-----------------------------------------------------------------------------

module Numeric.Dimensions.Idx
  ( -- * Data types
    Idx (), Idxs
  , idxFromWord, unsafeIdxFromWord, idxToWord
  , listIdxs, idxsFromWords
  ) where


import           Data.Coerce
import           Data.Constraint  (Dict (..))
import           Data.Data        (Data)
import           Foreign.Storable (Storable)
import           GHC.Enum
import           GHC.Generics     (Generic)
import qualified Text.Read        as P

#ifdef UNSAFE_INDICES
import GHC.Base (Int (..), Type, Word (..), int2Word#, unsafeCoerce#, word2Int#)
#else
import GHC.Base (Int (..), Type, Word (..), int2Word#, maxInt, plusWord2#,
                 timesWord2#, unsafeCoerce#, word2Int#)
#endif

import Numeric.Dimensions.Dim
import Numeric.TypedList      (typedListReadPrec, typedListShowsPrec)


-- | This type is used to index a single dimension;
--   the range of indices is from @0@ to @n-1@.
--
newtype Idx (n :: k) = Idx { unIdx :: Word }
  deriving ( Data, Generic, Integral, Real, Storable, Eq, Ord )

-- | Type-level dimensional indexing with arbitrary Word values inside.
--   Most of the operations on it require `Dimensions` constraint,
--   because the @Idxs@ itself does not store info about dimension bounds.
type Idxs (xs :: [k]) = TypedList Idx xs

-- | Convert an arbitrary Word to @Idx@.
--
--   If the word is outside of the bounds, fails with an error
--     (unless @unsafeindices@ flag is turned on).
--
unsafeIdxFromWord :: forall (k :: Type) (d :: k) . BoundedDim d => Word -> Idx d
#ifdef UNSAFE_INDICES
unsafeIdxFromWord = coerce
#else
unsafeIdxFromWord w
  | w < d     = Idx w
  | otherwise = errorWithoutStackTrace
              $ "idxFromWord{" ++ showIdxType @k @d ++ "}: word "
              ++ show w ++ " is outside of index bounds."
  where
    d = dimVal (dimBound @k @d)
#endif
{-# INLINE unsafeIdxFromWord #-}

-- | Convert an arbitrary Word to @Idx@.
idxFromWord :: forall (k :: Type) (d :: k) . BoundedDim d => Word -> Maybe (Idx d)
idxFromWord w
  | w < dimVal (dimBound @k @d) = Just (Idx w)
  | otherwise                   = Nothing
{-# INLINE idxFromWord #-}

-- | Get the value of an @Idx@.
idxToWord :: forall (k :: Type) (d :: k) . Idx d -> Word
idxToWord = coerce
{-# INLINE idxToWord #-}

{-# RULES
"fromIntegral/idxToWord"
  fromIntegral = idxToWord
  #-}

listIdxs :: forall (k :: Type) (xs :: [k]) . Idxs xs -> [Word]
listIdxs = unsafeCoerce#
{-# INLINE listIdxs #-}

idxsFromWords :: forall (k :: Type) (xs :: [k])
               . BoundedDims xs => [Word] -> Maybe (Idxs xs)
idxsFromWords = unsafeCoerce# . go (listDims (dimsBound @k @xs))
  where
    go :: [Word] -> [Word] -> Maybe [Word]
    go [] [] = Just []
    go (d : ds) (i : is)
      | i < d = (i:) <$> go ds is
    go _ _   = Nothing



instance BoundedDim x => Read (Idx (x :: k)) where
    readPrec = do
      w <- P.readPrec
      if w < dimVal (dimBound @k @x)
      then return (Idx w)
      else P.pfail
    readList = P.readListDefault
    readListPrec = P.readListPrecDefault

instance Show (Idx (x :: k)) where
    showsPrec d = showsPrec d . unIdx

instance BoundedDim n => Bounded (Idx (n :: k)) where
    minBound = 0
    {-# INLINE minBound #-}
    maxBound = coerce (dimVal(dimBound @k @n)  - 1)
    {-# INLINE maxBound #-}

instance BoundedDim n => Enum (Idx (n :: k)) where

#ifdef UNSAFE_INDICES
    succ = coerce ((+ 1) :: Word -> Word)
#else
    succ x@(Idx i)
      | x < maxBound = Idx (i + 1)
      | otherwise = succError $ showIdxType @k @n
#endif
    {-# INLINE succ #-}

#ifdef UNSAFE_INDICES
    pred = coerce (subtract 1 :: Word -> Word)
#else
    pred x@(Idx i)
      | x > minBound = Idx (i - 1)
      | otherwise = predError $ showIdxType @k @n
#endif
    {-# INLINE pred #-}

#ifdef UNSAFE_INDICES
    toEnum (I# i#) = coerce (W# (int2Word# i#))
#else
    toEnum i
        | i >= 0 && i' < d = coerce i'
        | otherwise        = toEnumError (showIdxType @k @n) i (0, d - 1)
      where
        d  = dimVal (dimBound @k @n)
        i' = fromIntegral i
#endif
    {-# INLINE toEnum #-}

#ifdef UNSAFE_INDICES
    fromEnum (Idx (W# w#)) = I# (word2Int# w#)
#else
    fromEnum (Idx x@(W# w#))
        | x <= maxIntWord = I# (word2Int# w#)
        | otherwise       = fromEnumError (showIdxType @k @n) x
        where
          maxIntWord = W# (case maxInt of I# i -> int2Word# i)
#endif
    {-# INLINE fromEnum #-}

    enumFrom (Idx n)
      = coerce (enumFromTo n (dimVal (dimBound @k @n) - 1))
    {-# INLINE enumFrom #-}
    enumFromThen (Idx n0) (Idx n1)
      = coerce (enumFromThenTo n0 n1 lim)
      where
        lim = if n1 >= n0 then dimVal (dimBound @k @n) - 1 else 0
    {-# INLINE enumFromThen #-}
    enumFromTo
      = coerce (enumFromTo :: Word -> Word -> [Word])
    {-# INLINE enumFromTo #-}
    enumFromThenTo
      = coerce (enumFromThenTo :: Word -> Word -> Word -> [Word])
    {-# INLINE enumFromThenTo #-}

instance BoundedDim n => Num (Idx (n :: k)) where

#ifdef UNSAFE_INDICES
    (+) = coerce ((+) :: Word -> Word -> Word)
#else
    (Idx a@(W# a#)) + b@(Idx (W# b#))
        | ovf || r >= d
          = errorWithoutStackTrace
          $ "Num.(+){" ++ showIdxType @k @n ++ "}: sum of "
            ++ show a ++ " and " ++ show b
            ++ " is outside of index bounds."
        | otherwise = Idx r
      where
        (ovf, r) = case plusWord2# a# b# of
          (# r2#, r1# #) -> ( W# r2# > 0 , W# r1# )
        d = dimVal (dimBound @k @n)
#endif
    {-# INLINE (+) #-}

#ifdef UNSAFE_INDICES
    (-) = coerce ((-) :: Word -> Word -> Word)
#else
    (Idx a) - (Idx b)
        | b > a
          = errorWithoutStackTrace
          $ "Num.(-){" ++ showIdxType @k @n ++ "}: difference of "
            ++ show a ++ " and " ++ show b
            ++ " is negative."
        | otherwise = Idx (a - b)
#endif
    {-# INLINE (-) #-}

#ifdef UNSAFE_INDICES
    (*) = coerce ((*) :: Word -> Word -> Word)
#else
    (Idx a@(W# a#)) * b@(Idx (W# b#))
        | ovf || r >= d
          = errorWithoutStackTrace
          $ "Num.(*){" ++ showIdxType @k @n ++ "}: product of "
            ++ show a ++ " and " ++ show b
            ++ " is outside of index bounds."
        | otherwise = Idx r
      where
        (ovf, r) = case timesWord2# a# b# of
          (# r2#, r1# #) -> ( W# r2# > 0 , W# r1# )
        d = dimVal (dimBound @k @n)
#endif
    {-# INLINE (*) #-}

    negate = errorWithoutStackTrace
           $ "Num.(*){" ++ showIdxType @k @n ++ "}: cannot negate index."
    {-# INLINE negate #-}
    abs = id
    {-# INLINE abs #-}
    signum = const (Idx 1)
    {-# INLINE signum #-}

#ifdef UNSAFE_INDICES
    fromInteger = coerce (fromInteger :: Integer -> Word)
#else
    fromInteger i
      | i >= 0 && i < d = Idx $ fromInteger i
      | otherwise       = errorWithoutStackTrace
                        $ "Num.fromInteger{" ++ showIdxType @k @n ++ "}: integer "
                        ++ show i ++ " is outside of index bounds."
      where
        d = toInteger $ dimVal (dimBound @k @n)
#endif
    {-# INLINE fromInteger #-}




instance Eq (Idxs (xs :: [k])) where
    (==) = unsafeCoerce# ((==) :: [Word] -> [Word] -> Bool)
    {-# INLINE (==) #-}

-- | Compare indices by their importance in lexicorgaphic order
--   from the first dimension to the last dimension
--   (the first dimension is the most significant one).
--
--   Literally,
--
--   > compare a b = compare (listIdxs a) (listIdxs b)
--
--   This is the same @compare@ rule, as for `Dims`.
--   This is also consistent with offsets:
--
--   > sort == sortOn fromEnum
--
instance Ord (Idxs (xs :: [k])) where
    compare = unsafeCoerce# (compare :: [Word] -> [Word] -> Ordering)
    {-# INLINE compare #-}

instance Show (Idxs (xs :: [k])) where
    showsPrec = typedListShowsPrec @k @Idx @xs showsPrec

instance BoundedDims xs => Read (Idxs (xs :: [k])) where
    readPrec = case inferAllBoundedDims @k @xs of
      Dict -> typedListReadPrec @k @BoundedDim P.readPrec (tList @k @xs)
    readList = P.readListDefault
    readListPrec = P.readListPrecDefault

-- | With this instance we can slightly reduce indexing expressions, e.g.
--
--   > x ! (1 :* 2 :* 4) == x ! (1 :* 2 :* 4 :* U)
--
instance BoundedDim n => Num (Idxs '[(n :: k)]) where
    (a:*U) + (b:*U) = (a+b) :* U
    {-# INLINE (+) #-}
    (a:*U) - (b:*U) = (a-b) :* U
    {-# INLINE (-) #-}
    (a:*U) * (b:*U) = (a*b) :* U
    {-# INLINE (*) #-}
    signum (a:*U)   = signum a :* U
    {-# INLINE signum #-}
    abs (a:*U)      = abs a :* U
    {-# INLINE abs #-}
    fromInteger i   = fromInteger i :* U
    {-# INLINE fromInteger #-}

instance BoundedDims ds => Bounded (Idxs (ds :: [k])) where
    maxBound = f (minDims @k @ds)
      where
        f :: forall (ns :: [k]) . Dims ns -> Idxs ns
        f U         = U
        f (d :* ds) = Idx (dimVal d - 1) :* f ds
    {-# INLINE maxBound #-}
    minBound = f (minDims @k @ds)
      where
        f :: forall (ns :: [k]) . Dims ns -> Idxs ns
        f U         = U
        f (_ :* ds) = Idx 0 :* f ds
    {-# INLINE minBound #-}

-- @ds@ must be @[Nat]@ for @Enum (Idxs ds)@,
--   because succ and pred would break otherwise
instance Dimensions ds => Enum (Idxs (ds :: [Nat])) where

    succ idx = case go dds idx of
        (True , _ ) -> succError $ showIdxsType dds
        (False, i') -> i'
      where
        dds = dims @ds
        go :: forall (ns :: [Nat]) . Dims ns -> Idxs ns -> (Bool, Idxs ns)
        go U U = (True, U)
        go (d :* ds) (Idx i :* is) = case go ds is of
          (True , is')
            | i + 1 == dimVal d -> (True , Idx  0    :* is')
            | otherwise         -> (False, Idx (i+1) :* is')
          (False, is')          -> (False, Idx  i    :* is')
    {-# INLINE succ #-}

    pred idx = case go dds idx of
        (True , _ ) -> predError $ showIdxsType dds
        (False, i') -> i'
      where
        dds = dims @ds
        go :: forall (ns :: [Nat]) . Dims ns -> Idxs ns -> (Bool, Idxs ns)
        go U U = (True, U)
        go (d :* ds) (Idx i :* is) = case go ds is of
          (True , is')
            | i == 0    -> (True , Idx (dimVal d - 1) :* is')
            | otherwise -> (False, Idx (i-1)          :* is')
          (False, is')  -> (False, Idx  i             :* is')
    {-# INLINE pred #-}

    toEnum off0 = case go dds of
        (0, i) -> i
        _      -> toEnumError (showIdxsType dds) off0 (0, totalDim dds - 1)
      where
        dds = dims @ds
        go :: forall (ns :: [Nat]) . Dims ns -> (Word, Idxs ns)
        go  U = (fromIntegral off0, U)
        go (d :* ds)
          | (off , is) <- go ds
          , (off', i ) <- quotRem off (dimVal d)
              = (off', Idx i :* is)
    {-# INLINE toEnum #-}

    fromEnum = fromIntegral . snd
             . foldr f (1, 0)
             . zip (listDims $ dims @ds) . listIdxs
      where
        f :: (Word, Word) -> (Word, Word) -> (Word, Word)
        f (d, i) (td, off) = (d * td, off + td * i)
    {-# INLINE fromEnum #-}

    enumFrom = unsafeCoerce# go True (dims @ds)
      where
        go :: Bool -> [Word] -> [Word] -> [[Word]]
        go b (d:ds) (i:is) =
          [ i' : is' | (b', i') <- zip (b : repeat False)
                                     $ enumFromTo (if b then i else 0) (d - 1)
                     , is' <- go b' ds is ]
        go _ _ _  = [[]]
    {-# INLINE enumFrom #-}

    enumFromTo = unsafeCoerce# go True True (dims @ds)
      where
        go :: Bool -> Bool -> [Word] -> [Word] -> [Word] -> [[Word]]
        go bl bu (d:ds) (x:xs) (y:ys) =
          [ i : is | (bl', bu', i) <- prepapp bl bu
                                    $ enumFromTo (if bl then x else 0)
                                                 (if bu then y else d - 1)
                   , is <- go bl' bu' ds xs ys ]
        go _ _ _ _ _ = [[]]
        prepapp _  _  []     = []
        prepapp bl bu [i]    = [(bl, bu, i)]
        prepapp bl bu (i:is) = (bl, False, i :: Word) : app bu is
        app _  []     = []
        app bu [i]    = [(False, bu, i :: Word)]
        app bu (i:is) = (False, False, i) : app bu is
    {-# INLINE enumFromTo #-}

    enumFromThen x0 x1 = case compare x1 x0 of
      EQ -> repeat x0
      GT -> enumFromThenTo x0 x1 maxBound
      LT -> enumFromThenTo x0 x1 minBound
    {-# INLINE enumFromThen #-}

    enumFromThenTo x0 x1 y = case dir of
        EQ -> if allYs >= allX0s then repeat x0 else []
        GT -> let (_, allDXs) = idxMinus allDs allX0s allX1s
                  repeatStep is
                    = if is <= allYs
                      then is : case idxPlus allDs is allDXs of
                        (0, is') -> repeatStep is'
                        _        -> []
                      else []
              in unsafeCoerce# (repeatStep allX0s)
        LT -> let (_, allDXs) = idxMinus allDs allX1s allX0s
                  repeatStep is
                    = if is >= allYs
                      then is : case idxMinus allDs allDXs is of
                        (0, is') -> repeatStep is'
                        _        -> []
                      else []
              in unsafeCoerce# (repeatStep allX0s)
      where
        allDs  = listDims $ dims @ds
        allX0s = listIdxs x0
        allX1s = listIdxs x1
        allYs  = listIdxs y
        dir    = compare allX1s allX0s -- succ or pred?
        -- second arg minus first arg
        idxMinus :: [Word] -> [Word] -> [Word] -> (Word, [Word])
        idxMinus (d:ds) (a:as) (b:bs)
          = let (one , xs ) = idxMinus ds as bs
                (one', x  ) = quotRem (d + b - a - one) d
            in  (1 - one', x : xs)
        idxMinus _ _ _ = (0, [])
        idxPlus :: [Word] -> [Word] -> [Word] -> (Word, [Word])
        idxPlus (d:ds) (a:as) (b:bs)
          = let (one , xs ) = idxPlus ds as bs
                (one', x  ) = quotRem (a + b + one) d
            in  (one', x : xs)
        idxPlus _ _ _ = (0, [])
    {-# INLINE enumFromThenTo #-}



-- | Show type of Idx (for displaying nice errors).
showIdxType :: forall (k :: Type) (x :: k) . BoundedDim x => String
showIdxType = "Idx " ++ show (dimVal (dimBound @k @x))

-- | Show type of Idxs (for displaying nice errors).
showIdxsType :: Dims ns -> String
showIdxsType ds = "Idxs '" ++ show (listDims ds)
