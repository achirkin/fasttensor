{-# LANGUAGE CPP                   #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MagicHash             #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeApplications      #-}
{-# LANGUAGE UnboxedTuples         #-}
{-# LANGUAGE UndecidableInstances  #-}
module Numeric.DataFrame.Internal.Backend.Family.DoubleX4 (DoubleX4 (..)) where


import           GHC.Base
import           Numeric.DataFrame.Internal.PrimArray
import           Numeric.PrimBytes
import           Numeric.ProductOrd
import qualified Numeric.ProductOrd.NonTransitive     as NonTransitive
import qualified Numeric.ProductOrd.Partial           as Partial


data DoubleX4 = DoubleX4# Double# Double# Double# Double#

-- | Since @Bounded@ is not implemented for floating point types, this instance
--   has an unresolvable constraint.
--   Nevetheless, it is good to have it here for nicer error messages.
instance Bounded Double => Bounded DoubleX4 where
    maxBound = case maxBound of D# x -> DoubleX4# x x x x
    minBound = case minBound of D# x -> DoubleX4# x x x x


instance Eq DoubleX4 where

    DoubleX4# a1 a2 a3 a4 == DoubleX4# b1 b2 b3 b4 =
      isTrue#
      (       (a1 ==## b1)
      `andI#` (a2 ==## b2)
      `andI#` (a3 ==## b3)
      `andI#` (a4 ==## b4)
      )
    {-# INLINE (==) #-}

    DoubleX4# a1 a2 a3 a4 /= DoubleX4# b1 b2 b3 b4 =
      isTrue#
      (      (a1 /=## b1)
      `orI#` (a2 /=## b2)
      `orI#` (a3 /=## b3)
      `orI#` (a4 /=## b4)
      )
    {-# INLINE (/=) #-}

cmp' :: Double# -> Double# -> PartialOrdering
cmp' a b
  | isTrue# (a >## b) = PGT
  | isTrue# (a <## b) = PLT
  | otherwise  = PEQ

instance ProductOrder DoubleX4 where
    cmp (DoubleX4# a1 a2 a3 a4) (DoubleX4# b1 b2 b3 b4)
      = cmp' a1 b1 <> cmp' a2 b2 <> cmp' a3 b3 <> cmp' a4 b4
    {-# INLINE cmp #-}

instance Ord (NonTransitive.ProductOrd DoubleX4) where
    NonTransitive.ProductOrd x > NonTransitive.ProductOrd y = cmp x y == PGT
    {-# INLINE (>) #-}
    NonTransitive.ProductOrd x < NonTransitive.ProductOrd y = cmp x y == PLT
    {-# INLINE (<) #-}
    (>=) (NonTransitive.ProductOrd (DoubleX4# a1 a2 a3 a4))
         (NonTransitive.ProductOrd (DoubleX4# b1 b2 b3 b4)) = isTrue#
      ((a1 >=## b1) `andI#` (a2 >=## b2) `andI#` (a3 >=## b3) `andI#` (a4 >=## b4))
    {-# INLINE (>=) #-}
    (<=) (NonTransitive.ProductOrd (DoubleX4# a1 a2 a3 a4))
         (NonTransitive.ProductOrd (DoubleX4# b1 b2 b3 b4)) = isTrue#
      ((a1 <=## b1) `andI#` (a2 <=## b2) `andI#` (a3 <=## b3) `andI#` (a4 <=## b4))
    {-# INLINE (<=) #-}
    compare (NonTransitive.ProductOrd a) (NonTransitive.ProductOrd b)
      = NonTransitive.toOrdering $ cmp a b
    {-# INLINE compare #-}
    min (NonTransitive.ProductOrd (DoubleX4# a1 a2 a3 a4))
        (NonTransitive.ProductOrd (DoubleX4# b1 b2 b3 b4))
      = NonTransitive.ProductOrd
        ( DoubleX4#
          (if isTrue# (a1 >## b1) then b1 else a1)
          (if isTrue# (a2 >## b2) then b2 else a2)
          (if isTrue# (a3 >## b3) then b3 else a3)
          (if isTrue# (a4 >## b4) then b4 else a4)
        )
    {-# INLINE min #-}
    max (NonTransitive.ProductOrd (DoubleX4# a1 a2 a3 a4))
        (NonTransitive.ProductOrd (DoubleX4# b1 b2 b3 b4))
      = NonTransitive.ProductOrd
        ( DoubleX4#
          (if isTrue# (a1 <## b1) then b1 else a1)
          (if isTrue# (a2 <## b2) then b2 else a2)
          (if isTrue# (a3 <## b3) then b3 else a3)
          (if isTrue# (a4 <## b4) then b4 else a4)
        )
    {-# INLINE max #-}

instance Ord (Partial.ProductOrd DoubleX4) where
    Partial.ProductOrd x > Partial.ProductOrd y = cmp x y == PGT
    {-# INLINE (>) #-}
    Partial.ProductOrd x < Partial.ProductOrd y = cmp x y == PLT
    {-# INLINE (<) #-}
    (>=) (Partial.ProductOrd (DoubleX4# a1 a2 a3 a4))
         (Partial.ProductOrd (DoubleX4# b1 b2 b3 b4)) = isTrue#
      ((a1 >=## b1) `andI#` (a2 >=## b2) `andI#` (a3 >=## b3) `andI#` (a4 >=## b4))
    {-# INLINE (>=) #-}
    (<=) (Partial.ProductOrd (DoubleX4# a1 a2 a3 a4))
         (Partial.ProductOrd (DoubleX4# b1 b2 b3 b4)) = isTrue#
      ((a1 <=## b1) `andI#` (a2 <=## b2) `andI#` (a3 <=## b3) `andI#` (a4 <=## b4))
    {-# INLINE (<=) #-}
    compare (Partial.ProductOrd a) (Partial.ProductOrd b)
      = Partial.toOrdering $ cmp a b
    {-# INLINE compare #-}
    min (Partial.ProductOrd (DoubleX4# a1 a2 a3 a4))
        (Partial.ProductOrd (DoubleX4# b1 b2 b3 b4))
      = Partial.ProductOrd
        ( DoubleX4#
          (if isTrue# (a1 >## b1) then b1 else a1)
          (if isTrue# (a2 >## b2) then b2 else a2)
          (if isTrue# (a3 >## b3) then b3 else a3)
          (if isTrue# (a4 >## b4) then b4 else a4)
        )
    {-# INLINE min #-}
    max (Partial.ProductOrd (DoubleX4# a1 a2 a3 a4))
        (Partial.ProductOrd (DoubleX4# b1 b2 b3 b4))
      = Partial.ProductOrd
        ( DoubleX4#
          (if isTrue# (a1 <## b1) then b1 else a1)
          (if isTrue# (a2 <## b2) then b2 else a2)
          (if isTrue# (a3 <## b3) then b3 else a3)
          (if isTrue# (a4 <## b4) then b4 else a4)
        )
    {-# INLINE max #-}

instance Ord DoubleX4 where
    DoubleX4# a1 a2 a3 a4 > DoubleX4# b1 b2 b3 b4
      | isTrue# (a1 >## b1) = True
      | isTrue# (a1 <## b1) = False
      | isTrue# (a2 >## b2) = True
      | isTrue# (a2 <## b2) = False
      | isTrue# (a3 >## b3) = True
      | isTrue# (a3 <## b3) = False
      | isTrue# (a4 >## b4) = True
      | otherwise           = False
    {-# INLINE (>) #-}

    DoubleX4# a1 a2 a3 a4 < DoubleX4# b1 b2 b3 b4
      | isTrue# (a1 <## b1) = True
      | isTrue# (a1 >## b1) = False
      | isTrue# (a2 <## b2) = True
      | isTrue# (a2 >## b2) = False
      | isTrue# (a3 <## b3) = True
      | isTrue# (a3 >## b3) = False
      | isTrue# (a4 <## b4) = True
      | otherwise           = False
    {-# INLINE (<) #-}

    DoubleX4# a1 a2 a3 a4 >= DoubleX4# b1 b2 b3 b4
      | isTrue# (a1 <## b1) = False
      | isTrue# (a1 >## b1) = True
      | isTrue# (a2 <## b2) = False
      | isTrue# (a2 >## b2) = True
      | isTrue# (a3 <## b3) = False
      | isTrue# (a3 >## b3) = True
      | isTrue# (a4 <## b4) = False
      | otherwise           = True
    {-# INLINE (>=) #-}

    DoubleX4# a1 a2 a3 a4 <= DoubleX4# b1 b2 b3 b4
      | isTrue# (a1 >## b1) = False
      | isTrue# (a1 <## b1) = True
      | isTrue# (a2 >## b2) = False
      | isTrue# (a2 <## b2) = True
      | isTrue# (a3 >## b3) = False
      | isTrue# (a3 <## b3) = True
      | isTrue# (a4 >## b4) = False
      | otherwise           = True
    {-# INLINE (<=) #-}

    compare (DoubleX4# a1 a2 a3 a4) (DoubleX4# b1 b2 b3 b4)
      | isTrue# (a1 >## b1) = GT
      | isTrue# (a1 <## b1) = LT
      | isTrue# (a2 >## b2) = GT
      | isTrue# (a2 <## b2) = LT
      | isTrue# (a3 >## b3) = GT
      | isTrue# (a3 <## b3) = LT
      | isTrue# (a4 >## b4) = GT
      | isTrue# (a4 <## b4) = LT
      | otherwise           = EQ
    {-# INLINE compare #-}



-- | element-wise operations for vectors
instance Num DoubleX4 where

    DoubleX4# a1 a2 a3 a4 + DoubleX4# b1 b2 b3 b4
      = DoubleX4# ((+##) a1 b1) ((+##) a2 b2) ((+##) a3 b3) ((+##) a4 b4)
    {-# INLINE (+) #-}

    DoubleX4# a1 a2 a3 a4 - DoubleX4# b1 b2 b3 b4
      = DoubleX4# ((-##) a1 b1) ((-##) a2 b2) ((-##) a3 b3) ((-##) a4 b4)
    {-# INLINE (-) #-}

    DoubleX4# a1 a2 a3 a4 * DoubleX4# b1 b2 b3 b4
      = DoubleX4# ((*##) a1 b1) ((*##) a2 b2) ((*##) a3 b3) ((*##) a4 b4)
    {-# INLINE (*) #-}

    negate (DoubleX4# a1 a2 a3 a4) = DoubleX4#
      (negateDouble# a1) (negateDouble# a2) (negateDouble# a3) (negateDouble# a4)
    {-# INLINE negate #-}

    abs (DoubleX4# a1 a2 a3 a4)
      = DoubleX4#
      (if isTrue# (a1 >=## 0.0##) then a1 else negateDouble# a1)
      (if isTrue# (a2 >=## 0.0##) then a2 else negateDouble# a2)
      (if isTrue# (a3 >=## 0.0##) then a3 else negateDouble# a3)
      (if isTrue# (a4 >=## 0.0##) then a4 else negateDouble# a4)
    {-# INLINE abs #-}

    signum (DoubleX4# a1 a2 a3 a4)
      = DoubleX4# (if isTrue# (a1 >## 0.0##)
                  then 1.0##
                  else if isTrue# (a1 <## 0.0##) then -1.0## else 0.0## )
                 (if isTrue# (a2 >## 0.0##)
                  then 1.0##
                  else if isTrue# (a2 <## 0.0##) then -1.0## else 0.0## )
                 (if isTrue# (a3 >## 0.0##)
                  then 1.0##
                  else if isTrue# (a3 <## 0.0##) then -1.0## else 0.0## )
                 (if isTrue# (a4 >## 0.0##)
                  then 1.0##
                  else if isTrue# (a4 <## 0.0##) then -1.0## else 0.0## )
    {-# INLINE signum #-}

    fromInteger n = case fromInteger n of D# x -> DoubleX4# x x x x
    {-# INLINE fromInteger #-}



instance Fractional DoubleX4 where

    DoubleX4# a1 a2 a3 a4 / DoubleX4# b1 b2 b3 b4 = DoubleX4#
      ((/##) a1 b1) ((/##) a2 b2) ((/##) a3 b3) ((/##) a4 b4)
    {-# INLINE (/) #-}

    recip (DoubleX4# a1 a2 a3 a4) = DoubleX4#
      ((/##) 1.0## a1) ((/##) 1.0## a2) ((/##) 1.0## a3) ((/##) 1.0## a4)
    {-# INLINE recip #-}

    fromRational r = case fromRational r of D# x -> DoubleX4# x x x x
    {-# INLINE fromRational #-}



instance Floating DoubleX4 where

    pi = DoubleX4#
      3.141592653589793238##
      3.141592653589793238##
      3.141592653589793238##
      3.141592653589793238##
    {-# INLINE pi #-}

    exp (DoubleX4# a1 a2 a3 a4) = DoubleX4#
      (expDouble# a1) (expDouble# a2) (expDouble# a3) (expDouble# a4)
    {-# INLINE exp #-}

    log (DoubleX4# a1 a2 a3 a4) = DoubleX4#
      (logDouble# a1) (logDouble# a2) (logDouble# a3) (logDouble# a4)
    {-# INLINE log #-}

    sqrt (DoubleX4# a1 a2 a3 a4) = DoubleX4#
      (sqrtDouble# a1) (sqrtDouble# a2) (sqrtDouble# a3) (sqrtDouble# a4)
    {-# INLINE sqrt #-}

    sin (DoubleX4# a1 a2 a3 a4) = DoubleX4#
      (sinDouble# a1) (sinDouble# a2) (sinDouble# a3) (sinDouble# a4)
    {-# INLINE sin #-}

    cos (DoubleX4# a1 a2 a3 a4) = DoubleX4#
      (cosDouble# a1) (cosDouble# a2) (cosDouble# a3) (cosDouble# a4)
    {-# INLINE cos #-}

    tan (DoubleX4# a1 a2 a3 a4) = DoubleX4#
      (tanDouble# a1) (tanDouble# a2) (tanDouble# a3) (tanDouble# a4)
    {-# INLINE tan #-}

    asin (DoubleX4# a1 a2 a3 a4) = DoubleX4#
      (asinDouble# a1) (asinDouble# a2) (asinDouble# a3) (asinDouble# a4)
    {-# INLINE asin #-}

    acos (DoubleX4# a1 a2 a3 a4) = DoubleX4#
      (acosDouble# a1) (acosDouble# a2) (acosDouble# a3) (acosDouble# a4)
    {-# INLINE acos #-}

    atan (DoubleX4# a1 a2 a3 a4) = DoubleX4#
      (atanDouble# a1) (atanDouble# a2) (atanDouble# a3) (atanDouble# a4)
    {-# INLINE atan #-}

    sinh (DoubleX4# a1 a2 a3 a4) = DoubleX4#
      (sinhDouble# a1) (sinhDouble# a2) (sinhDouble# a3) (sinhDouble# a4)
    {-# INLINE sinh #-}

    cosh (DoubleX4# a1 a2 a3 a4) = DoubleX4#
      (coshDouble# a1) (coshDouble# a2) (coshDouble# a3) (coshDouble# a4)
    {-# INLINE cosh #-}

    tanh (DoubleX4# a1 a2 a3 a4) = DoubleX4#
      (tanhDouble# a1) (tanhDouble# a2) (tanhDouble# a3) (tanhDouble# a4)
    {-# INLINE tanh #-}

    DoubleX4# a1 a2 a3 a4 ** DoubleX4# b1 b2 b3 b4 = DoubleX4#
      ((**##) a1 b1) ((**##) a2 b2) ((**##) a3 b3) ((**##) a4 b4)
    {-# INLINE (**) #-}

    logBase x y         =  log y / log x
    {-# INLINE logBase #-}

    asinh x = log (x + sqrt (1.0+x*x))
    {-# INLINE asinh #-}

    acosh x = log (x + (x+1.0) * sqrt ((x-1.0)/(x+1.0)))
    {-# INLINE acosh #-}

    atanh x = 0.5 * log ((1.0+x) / (1.0-x))
    {-# INLINE atanh #-}

-- offset in bytes is S times bigger than offset in prim elements,
-- when S is power of two, this is equal to shift
#define BOFF_TO_PRIMOFF(off) uncheckedIShiftRL# off 3#
#define ELEM_N 4

instance PrimBytes DoubleX4 where

    getBytes (DoubleX4# a1 a2 a3 a4) = case runRW#
       ( \s0 -> case newByteArray# (byteSize @DoubleX4 undefined) s0 of
           (# s1, marr #) -> case writeDoubleArray# marr 0# a1 s1 of
             s2 -> case writeDoubleArray# marr 1# a2 s2 of
               s3 -> case writeDoubleArray# marr 2# a3 s3 of
                 s4 -> case writeDoubleArray# marr 3# a4 s4 of
                   s5 -> unsafeFreezeByteArray# marr s5
       ) of (# _, a #) -> a
    {-# INLINE getBytes #-}

    fromBytes off arr
      | i <- BOFF_TO_PRIMOFF(off)
      = DoubleX4#
      (indexDoubleArray# arr i)
      (indexDoubleArray# arr (i +# 1#))
      (indexDoubleArray# arr (i +# 2#))
      (indexDoubleArray# arr (i +# 3#))
    {-# INLINE fromBytes #-}

    readBytes mba off s0
      | i <- BOFF_TO_PRIMOFF(off)
      = case readDoubleArray# mba i s0 of
      (# s1, a1 #) -> case readDoubleArray# mba (i +# 1#) s1 of
        (# s2, a2 #) -> case readDoubleArray# mba (i +# 2#) s2 of
          (# s3, a3 #) -> case readDoubleArray# mba (i +# 3#) s3 of
            (# s4, a4 #) -> (# s4, DoubleX4# a1 a2 a3 a4 #)
    {-# INLINE readBytes #-}

    writeBytes mba off (DoubleX4# a1 a2 a3 a4) s
      | i <- BOFF_TO_PRIMOFF(off)
      = writeDoubleArray# mba (i +# 3#) a4
      ( writeDoubleArray# mba (i +# 2#) a3
      ( writeDoubleArray# mba (i +# 1#) a2
      ( writeDoubleArray# mba  i        a1 s )))
    {-# INLINE writeBytes #-}

    readAddr addr s0
      = case readDoubleOffAddr# addr 0# s0 of
      (# s1, a1 #) -> case readDoubleOffAddr# addr 1# s1 of
        (# s2, a2 #) -> case readDoubleOffAddr# addr 2# s2 of
          (# s3, a3 #) -> case readDoubleOffAddr# addr 3# s3 of
            (# s4, a4 #) -> (# s4, DoubleX4# a1 a2 a3 a4 #)
    {-# INLINE readAddr #-}

    writeAddr (DoubleX4# a1 a2 a3 a4) addr s
      = writeDoubleOffAddr# addr 3# a4
      ( writeDoubleOffAddr# addr 2# a3
      ( writeDoubleOffAddr# addr 1# a2
      ( writeDoubleOffAddr# addr 0# a1 s )))
    {-# INLINE writeAddr #-}

    byteSize _ = byteSize @Double undefined *# ELEM_N#
    {-# INLINE byteSize #-}

    byteAlign _ = byteAlign @Double undefined
    {-# INLINE byteAlign #-}

    byteOffset _ = 0#
    {-# INLINE byteOffset #-}

    byteFieldOffset _ _ = negateInt# 1#
    {-# INLINE byteFieldOffset #-}

    indexArray ba off
      | i <- off *# ELEM_N#
      = DoubleX4#
      (indexDoubleArray# ba i)
      (indexDoubleArray# ba (i +# 1#))
      (indexDoubleArray# ba (i +# 2#))
      (indexDoubleArray# ba (i +# 3#))
    {-# INLINE indexArray #-}

    readArray mba off s0
      | i <- off *# ELEM_N#
      = case readDoubleArray# mba i s0 of
      (# s1, a1 #) -> case readDoubleArray# mba (i +# 1#) s1 of
        (# s2, a2 #) -> case readDoubleArray# mba (i +# 2#) s2 of
          (# s3, a3 #) -> case readDoubleArray# mba (i +# 3#) s3 of
            (# s4, a4 #) -> (# s4, DoubleX4# a1 a2 a3 a4 #)
    {-# INLINE readArray #-}

    writeArray mba off (DoubleX4# a1 a2 a3 a4) s
      | i <- off *# ELEM_N#
      = writeDoubleArray# mba (i +# 3#) a4
      ( writeDoubleArray# mba (i +# 2#) a3
      ( writeDoubleArray# mba (i +# 1#) a2
      ( writeDoubleArray# mba  i        a1 s )))
    {-# INLINE writeArray #-}


instance PrimArray Double DoubleX4 where

    broadcast# (D# x) = DoubleX4# x x x x
    {-# INLINE broadcast# #-}

    ix# 0# (DoubleX4# a1 _ _ _) = D# a1
    ix# 1# (DoubleX4# _ a2 _ _) = D# a2
    ix# 2# (DoubleX4# _ _ a3 _) = D# a3
    ix# 3# (DoubleX4# _ _ _ a4) = D# a4
    ix# _   _                   = undefined
    {-# INLINE ix# #-}

    gen# _ f s0 = case f s0 of
      (# s1, D# a1 #) -> case f s1 of
        (# s2, D# a2 #) -> case f s2 of
          (# s3, D# a3 #) -> case f s3 of
            (# s4, D# a4 #) -> (# s4, DoubleX4# a1 a2 a3 a4 #)


    upd# _ 0# (D# q) (DoubleX4# _ y z w) = DoubleX4# q y z w
    upd# _ 1# (D# q) (DoubleX4# x _ z w) = DoubleX4# x q z w
    upd# _ 2# (D# q) (DoubleX4# x y _ w) = DoubleX4# x y q w
    upd# _ 3# (D# q) (DoubleX4# x y z _) = DoubleX4# x y z q
    upd# _ _ _ x                         = x
    {-# INLINE upd# #-}

    withArrayContent# _ g x = g (CumulDims [ELEM_N, 1]) 0# (getBytes x)
    {-# INLINE withArrayContent# #-}

    offsetElems _ = 0#
    {-# INLINE offsetElems #-}

    uniqueOrCumulDims _ = Right (CumulDims [ELEM_N, 1])
    {-# INLINE uniqueOrCumulDims #-}

    fromElems# _ off ba = DoubleX4#
      (indexDoubleArray# ba off)
      (indexDoubleArray# ba (off +# 1#))
      (indexDoubleArray# ba (off +# 2#))
      (indexDoubleArray# ba (off +# 3#))
    {-# INLINE fromElems# #-}
