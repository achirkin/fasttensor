{-# LANGUAGE CPP                    #-}
{-# LANGUAGE DataKinds              #-}
{-# LANGUAGE ExplicitForAll         #-}
{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE GADTs                  #-}
{-# LANGUAGE MagicHash              #-}
{-# LANGUAGE MultiParamTypeClasses  #-}
{-# LANGUAGE PolyKinds              #-}
{-# LANGUAGE TypeOperators          #-}
{-# LANGUAGE UnboxedTuples          #-}
module Numeric.DataFrame.Internal.PrimArray
  ( PrimArray (..), CumulDims (..)
  , cumulDims, cdTotalDim, cdTotalDim#
  , cdIx, cdIxSub, getOffAndSteps, getOffAndStepsSub
  , cdIxM, getOffAndStepsM, getOffAndStepsSubM
  , ixOff, unsafeFromFlatList, getSteps, fromSteps
  , withArrayContent, fromElems, broadcast
  ) where

import Control.Arrow  ((***))
import Data.Monoid    as Mon (Monoid (..))
import Data.Semigroup as Sem (Semigroup (..))
import GHC.Base       hiding (foldr)
 -- (ByteArray#, Int (..), Int#, RuntimeRep (..), Type,
 --                           Word (..), inline, runRW#, touch#, word2Int#, (+#))
import GHC.Exts           (TYPE)
import Numeric.Dimensions
import Numeric.PrimBytes


-- | Given @Dims ns@, @CumulativeDims@ is a list of length @Length ns + 1@;
--   which cumulative @totalDim@ accumulated on the right.
--   In particular, its first element is @totalDim ds@,
--   its last element is always is always @1@.
newtype CumulDims = CumulDims { unCumulDims :: [Word] }
  deriving Show

instance Sem.Semigroup CumulDims where
    CumulDims as <> CumulDims bs = CumulDims $ map (head bs *) (init as) ++ bs

instance Mon.Monoid CumulDims where
    mempty = CumulDims [1]
#if !(MIN_VERSION_base(4,11,0))
    mappend = (<>)
#endif


-- | Calculate cumulative dims
cumulDims :: Dims (ns :: [k]) -> CumulDims
cumulDims = CumulDims . uncurry (:)
          . foldr (\d (c, cs) -> (c*d,c:cs)) (1, []) . listDims

-- | Get the total number of elements
cdTotalDim :: CumulDims -> Word
cdTotalDim ~(CumulDims ~(n:_)) = n

cdTotalDim# :: CumulDims -> Int#
cdTotalDim# ~(CumulDims ~(n:_)) = case n of W# w -> word2Int# w

-- | Calculate offset of an Idxs
--
--   Note, you can take offset of subspace with CumulDims of larger space
--     - very convenient!
--
--   If any of the dims in @ns@ is unknown (@n ~ XN m@),
--   then this function is unsafe and can throw an `OutOfDimBounds` exception.
--   Otherwise, its safety is guaranteed by the type system.
cdIx :: CumulDims -> Idxs ns -> Int
cdIx steps
  = fromIntegral . fst . getOffAndSteps' 0 0 (unCumulDims steps) . listIdxs

-- | Calculate offset of an Idxs.
--
--   Also check if the last index plus dimVal of subN is not bigger than the
--   corresponding dim inside CumulDims; throw an `OutOfDimBounds` otherwise.
--
--   If any of the dims in @ns@ is unknown (@n ~ XN m@),
--   then this function is unsafe and can throw an `OutOfDimBounds` exception.
--   Otherwise, its safety is guaranteed by the type system.
cdIxSub :: CumulDims -> Idxs (ns +: idxN) -> Dim subN -> Int
cdIxSub steps idxs d
  = fromIntegral
  . fst . getOffAndSteps' (dimVal d) 0 (unCumulDims steps) $ listIdxs idxs

-- | Calculate offset of an Idxs and return remaining CumulDims.
--
--   If any of the dims in @ns@ is unknown (@n ~ XN m@),
--   then this function is unsafe and can throw an `OutOfDimBounds` exception.
--   Otherwise, its safety is guaranteed by the type system.
getOffAndSteps :: Int -- ^ Initial offset
               -> CumulDims -> Idxs ns -> (Int, CumulDims)
getOffAndSteps off0 steps
  = (fromIntegral *** CumulDims)
  . getOffAndSteps' 0 (fromIntegral off0) (unCumulDims steps) . listIdxs

-- | Calculate offset of an Idxs and return remaining CumulDims.
--
--   Also check if the last index plus dimVal of subN is not bigger than the
--   corresponding dim inside CumulDims; throw an `OutOfDimBounds` otherwise.
--
--   If any of the dims in @ns@ is unknown (@n ~ XN m@),
--   then this function is unsafe and can throw an `OutOfDimBounds` exception.
--   Otherwise, its safety is guaranteed by the type system.
getOffAndStepsSub :: Int -- ^ Initial offset
                  -> CumulDims -> Idxs (ns +: idxN)
                  -> Dim subN -> (Int, CumulDims)
getOffAndStepsSub off0 steps idxs d
  = (fromIntegral *** CumulDims)
  . getOffAndSteps' (dimVal d) (fromIntegral off0) (unCumulDims steps)
  $ listIdxs idxs


getOffAndSteps' :: Word -> Word -> [Word] -> [Word] -> (Word, [Word])
getOffAndSteps' sub0 off0 steps0 is0 = go sub0 off0 steps0 is0
  where
#ifndef UNSAFE_INDICES
    ds0 = case fromSteps (CumulDims steps0) of SomeDims x -> listDims x
#endif
    go :: Word -> Word -> [Word] -> [Word] -> (Word, [Word])
    go 0 off steps [] = (off, steps)
    go sub off ~(steps@(s:_)) [] = (off, sub*s : steps)
#ifndef UNSAFE_INDICES
    go sub _ ~(bs:(s:_)) [i]
      | b <- quot bs s
      , sub > 0 && i + sub > b
      = outOfDimBoundsNoCallStack
          "{Calculating SubDataFrame offset}"
          i b (Just sub) (Just (ds0, is0))
    go _ _ ~(bs:(s:_)) (i:_)
      | b <- quot bs s
      , i >= b
      = outOfDimBoundsNoCallStack
          "{Calculating SubDataFrame offset}"
          i b Nothing (Just (ds0, is0))
#endif
    go sub off ~(_:steps@(s:_)) (i:ixs)
      = go sub (off + i*s) steps ixs
{-# INLINE getOffAndSteps' #-}



-- | Same as `cdIx`, but safe; returns @Nothing@ if out of bounds.
cdIxM :: CumulDims -> Idxs ns -> Maybe Int
cdIxM steps
  = fmap (fromIntegral . fst)
  . getOffAndStepsM' 0 0 (unCumulDims steps) . listIdxs

-- | Same as `getOffAndSteps`, but safe; returns @Nothing@ if out of bounds.
--   Trims the first (slicing) dimension of the returned CumulDims to fit
--   the original dataframe if necessary.
getOffAndStepsM :: Int -- ^ Initial offset
                -> CumulDims -> Idxs ns -> Maybe (Int, CumulDims)
getOffAndStepsM off0 steps
  = fmap (fromIntegral *** CumulDims)
  . getOffAndStepsM' 0 (fromIntegral off0) (unCumulDims steps) . listIdxs

-- | Same as `getOffAndStepsSub`, but safe; returns @Nothing@ if out of bounds.
--   Trims the first (slicing) dimension of the returned CumulDims to fit
--   the original dataframe if necessary.
getOffAndStepsSubM :: Int -- ^ Initial offset
                  -> CumulDims -> Idxs (ns +: idxN)
                  -> Dim subN -> Maybe (Int, CumulDims)
getOffAndStepsSubM off0 steps idxs d
  = fmap (fromIntegral *** CumulDims)
  . getOffAndStepsM' (dimVal d) (fromIntegral off0) (unCumulDims steps)
  $ listIdxs idxs

getOffAndStepsM' :: Word -> Word -> [Word] -> [Word] -> Maybe (Word, [Word])
getOffAndStepsM' = go
  where
    go :: Word -> Word -> [Word] -> [Word] -> Maybe (Word, [Word])
    go _   off steps [] = Just (off, steps)
    go sub off ~(bs:steps@(s:_)) (i:ixs)
      | is >= bs       = Nothing
      | not (null ixs) = go sub (off + is) steps ixs
      | sub == 0       = Just (off + is, steps)
      | otherwise      = Just (off + is, min (bs - is) (sub*s) : steps)
      where
        is = i*s
{-# INLINE getOffAndStepsM' #-}

-- | Try to get @CumulDims@ from an array,
--   and create it using @Dims@ if failed.
getSteps :: PrimArray t a => Dims (ns :: [k]) -> a -> CumulDims
getSteps dds = withArrayContent (const $ cumulDims dds) (\cd _ _ -> cd)
{-# INLINE getSteps #-}

-- | Get @Dims@ by "de-accumulating" @CumulDims@.
fromSteps :: CumulDims -> SomeDims
fromSteps = someDimsVal . f . unCumulDims
  where
    -- ignore last value, which is always 1
    f :: [Word] -> [Word]
    f []       = []
    f [_]      = []
    f [n,_]    = [n]
    f (a:b:cs) = a `quot` b : f (b:cs)
{-# INLINE fromSteps #-}

class PrimBytes t => PrimArray t a | a -> t where
    -- | Broadcast element into array
    --
    --   Warning: do not use this function at the call site; use `broadcast`
    --            instead. Otherwise you will miss some rewrite rules.
    broadcast# :: t -> a
    -- | Index an array given an offset
    ix# :: Int# -> a -> t
    ix# i = withArrayContent id (\_ off arr -> indexArray arr (off +# i))
    {-# INLINE ix# #-}
    -- | Generate an array using an accumulator funtion
    gen# :: CumulDims
            -- ^ Dimensionality of the result array;
            --   Be careful! @ns@ depends on @a@, but this is not reflected in
            --   types and is not checked at runtime.
         -> (s -> (# s, t #))
         -> s -> (# s, a #)
    -- | update a single element in an array given an offset
    upd# :: CumulDims
            -- ^ Dimensionality of the result array;
            --   Be careful! @ns@ depends on @a@, but this is not reflected in
            --   types and is not checked at runtime.
         -> Int# -> t -> a -> a

    -- | If the array is represented as a single broadcasted value, return this
    --   this value. Otherwise, return the full array content:
    --    @CumulDims@, array offset (elements), byte array with the content.
    --
    --   Warning: never use this function directly. Use `withArrayContent` instead.
    --            There is a bug in GHC 8.6, such that certain optimizations
    --            (probably, instance specialization/rewrite rules) break the code,
    --            which is only observable at runtime. The effect is that the
    --            content of a `ByteArray#` becomes a garbage. The workaround is
    --            to use a non-inlinable wrapper to disable these optimizations.
    --            In addition, the wrapper function has some rewrite rules, which
    --            can potentially improve performance with other GHC versions.
    withArrayContent# :: forall (rep :: RuntimeRep) (r :: TYPE rep)
                       . (t -> r)
                      -> (CumulDims -> Int# -> ByteArray# -> r)
                      -> a -> r

    -- | Offset of an array as a number of elements
    offsetElems :: a -> Int#
    offsetElems a = withArrayContent (\_ f -> f 0#) (const $ \o _ f -> f o) a (\i -> i)
    {-# INLINE offsetElems #-}

    -- | Normally, this returns a cumulative @totalDim@s.
    --   However, if a particular implementation does not have the dimensionality
    --   information, it cannot return @CumulDims@;
    --   In this case, it is a sign that all elements of an array are same.
    --   Thus, it is possible to return the single element value instead.
    --
    --   Note, this function returns the only unique element only if it is
    --   a such by construction (there is no equality checks involved).
    uniqueOrCumulDims :: a -> Either t CumulDims
    uniqueOrCumulDims = withArrayContent Left (\cd _ _ -> Right cd)
    {-# INLINE uniqueOrCumulDims #-}

    -- | Define an array by its offset and cumulative dims in a ByteArray.
    --   Both offset and dims are given in element number (not in bytes).
    --
    --   Warning: never use this function directly. Use `fromElems` instead.
    --            There is a bug in GHC 8.6, such that certain optimizations
    --            (probably, instance specialization/rewrite rules) break the code,
    --            which is only observable at runtime. The effect is that the
    --            content of a `ByteArray#` becomes a garbage. The workaround is
    --            to use a non-inlinable wrapper to disable these optimizations.
    --            In addition, the wrapper function has some rewrite rules, which
    --            can potentially improve performance with other GHC versions.
    fromElems# :: CumulDims -> Int# -> ByteArray# -> a

{-# WARNING fromElems# "Please, use fromElems instead." #-}
{-# WARNING withArrayContent# "Please, use withArrayContent instead." #-}

-- | Index array by an integer offset (starting from 0).
ixOff :: PrimArray t a => Int -> a -> t
ixOff (I# i) = ix# i

-- | Construct an array from a flat list and @Dims@;
--   Be careful! @ns@ depends on @a@, but this is not reflected in
--   types and is not checked at runtime.
unsafeFromFlatList :: PrimArray t a => Dims ns -> t -> [t] -> a
unsafeFromFlatList ds x0 vs = case gen# (cumulDims ds) f vs of (# _, r #) -> r
  where
    f []     = (# [], x0 #)
    f (x:xs) = (# xs, x #)

-- | If the array is represented as a single broadcasted value, return this
--   this value. Otherwise, return the full array content:
--    @CumulDims@, array offset (elements), byte array with the content.
withArrayContent :: forall (t :: Type) (a :: Type)
                           (rep :: RuntimeRep) (r :: TYPE rep)
                  . PrimArray t a
                 => (t -> r)
                 -> (CumulDims -> Int# -> ByteArray# -> r)
                 -> a -> r
withArrayContent = withArrayContent#
#if __GLASGOW_HASKELL__ == 806
{-# NOINLINE withArrayContent #-}
#else
{-# INLINE[1] withArrayContent #-}
#endif

-- | Define an array by its offset and cumulative dims in a ByteArray.
--   Both offset and dims are given in element number (not in bytes).
--
--   It is better to use this function instead of @fromBytes@ to avoid
--   recalculating @CumulDims@ for implementations that require it.
fromElems :: forall (t :: Type) (a :: Type)
           . PrimArray t a => CumulDims -> Int# -> ByteArray# -> a
fromElems = fromElems#
#if __GLASGOW_HASKELL__ == 806
{-# NOINLINE fromElems #-}
#else
{-# INLINE[1] fromElems #-}
#endif

-- | Broadcast element into array
broadcast :: forall (t :: Type) (a :: Type)
           . PrimArray t a => t -> a
broadcast = broadcast#
{-# INLINE[1] broadcast #-}

{-# RULES

"withArrayContent/id"
  withArrayContent broadcast fromElems = id

"withArrayContent+fromElems" forall f g cd off ba .
  withArrayContent f g (fromElems cd off ba) = g cd off ba

"withArrayContent+broadcast" forall f g e .
  withArrayContent f g (broadcast e) = f e
  #-}
