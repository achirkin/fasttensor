{-# LANGUAGE MagicHash             #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeApplications      #-}
{-# LANGUAGE UnboxedTuples         #-}
module Numeric.DataFrame.Internal.Array.Family.FloatX4 (FloatX4 (..)) where


import           GHC.Base
import           Numeric.DataFrame.Internal.Array.Class
import           Numeric.PrimBytes


data FloatX4 k = FloatX4# Float# Float# Float# Float#


instance Bounded (FloatX4 k) where
    maxBound = case infty of F# x -> FloatX4# x x x x
    minBound = case negate infty of F# x -> FloatX4# x x x x

infty :: Float
infty = read "Infinity"

instance Show (FloatX4 k) where
    show (FloatX4# a1 a2 a3 a4)
      =  "{ " ++ show (F# a1)
      ++ ", " ++ show (F# a2)
      ++ ", " ++ show (F# a3)
      ++ ", " ++ show (F# a4)
      ++ " }"



instance Eq (FloatX4 k) where

    FloatX4# a1 a2 a3 a4 == FloatX4# b1 b2 b3 b4 =
      isTrue#
      (       (a1 `eqFloat#` b1)
      `andI#` (a2 `eqFloat#` b2)
      `andI#` (a3 `eqFloat#` b3)
      `andI#` (a4 `eqFloat#` b4)
      )
    {-# INLINE (==) #-}

    FloatX4# a1 a2 a3 a4 /= FloatX4# b1 b2 b3 b4 =
      isTrue#
      (      (a1 `neFloat#` b1)
      `orI#` (a2 `neFloat#` b2)
      `orI#` (a3 `neFloat#` b3)
      `orI#` (a4 `neFloat#` b4)
      )
    {-# INLINE (/=) #-}



-- | Implement partial ordering for `>`, `<`, `>=`, `<=`
--           and lexicographical ordering for `compare`
instance Ord (FloatX4 k) where
    FloatX4# a1 a2 a3 a4 > FloatX4# b1 b2 b3 b4 =
      isTrue#
      (       (a1 `gtFloat#` b1)
      `andI#` (a2 `gtFloat#` b2)
      `andI#` (a3 `gtFloat#` b3)
      `andI#` (a4 `gtFloat#` b4)
      )
    {-# INLINE (>) #-}

    FloatX4# a1 a2 a3 a4 < FloatX4# b1 b2 b3 b4 =
      isTrue#
      (       (a1 `ltFloat#` b1)
      `andI#` (a2 `ltFloat#` b2)
      `andI#` (a3 `ltFloat#` b3)
      `andI#` (a4 `ltFloat#` b4)
      )
    {-# INLINE (<) #-}

    FloatX4# a1 a2 a3 a4 >= FloatX4# b1 b2 b3 b4 =
      isTrue#
      (       (a1 `geFloat#` b1)
      `andI#` (a2 `geFloat#` b2)
      `andI#` (a3 `geFloat#` b3)
      `andI#` (a4 `geFloat#` b4)
      )
    {-# INLINE (>=) #-}

    FloatX4# a1 a2 a3 a4 <= FloatX4# b1 b2 b3 b4 =
      isTrue#
      (       (a1 `leFloat#` b1)
      `andI#` (a2 `leFloat#` b2)
      `andI#` (a3 `leFloat#` b3)
      `andI#` (a4 `leFloat#` b4)
      )
    {-# INLINE (<=) #-}

    -- | Compare lexicographically
    compare (FloatX4# a1 a2 a3 a4) (FloatX4# b1 b2 b3 b4)
      | isTrue# (a1 `gtFloat#` b1) = GT
      | isTrue# (a1 `ltFloat#` b1) = LT
      | isTrue# (a2 `gtFloat#` b2) = GT
      | isTrue# (a2 `ltFloat#` b2) = LT
      | isTrue# (a3 `gtFloat#` b3) = GT
      | isTrue# (a3 `ltFloat#` b3) = LT
      | isTrue# (a4 `gtFloat#` b4) = GT
      | isTrue# (a4 `ltFloat#` b4) = LT
      | otherwise = EQ
    {-# INLINE compare #-}

    -- | Element-wise minimum
    min (FloatX4# a1 a2 a3 a4) (FloatX4# b1 b2 b3 b4) = FloatX4#
      (if isTrue# (a1 `gtFloat#` b1) then b1 else a1)
      (if isTrue# (a2 `gtFloat#` b2) then b2 else a2)
      (if isTrue# (a3 `gtFloat#` b3) then b3 else a3)
      (if isTrue# (a4 `gtFloat#` b4) then b4 else a4)
    {-# INLINE min #-}

    -- | Element-wise maximum
    max (FloatX4# a1 a2 a3 a4) (FloatX4# b1 b2 b3 b4) = FloatX4#
      (if isTrue# (a1 `gtFloat#` b1) then a1 else b1)
      (if isTrue# (a2 `gtFloat#` b2) then a2 else b2)
      (if isTrue# (a3 `gtFloat#` b3) then a3 else b3)
      (if isTrue# (a4 `gtFloat#` b4) then a4 else b4)
    {-# INLINE max #-}



-- | element-wise operations for vectors
instance Num (FloatX4 k) where

    FloatX4# a1 a2 a3 a4 + FloatX4# b1 b2 b3 b4
      = FloatX4# (plusFloat# a1 b1) (plusFloat# a2 b2) (plusFloat# a3 b3) (plusFloat# a4 b4)
    {-# INLINE (+) #-}

    FloatX4# a1 a2 a3 a4 - FloatX4# b1 b2 b3 b4
      = FloatX4# (minusFloat# a1 b1) (minusFloat# a2 b2) (minusFloat# a3 b3) (minusFloat# a4 b4)
    {-# INLINE (-) #-}

    FloatX4# a1 a2 a3 a4 * FloatX4# b1 b2 b3 b4
      = FloatX4# (timesFloat# a1 b1) (timesFloat# a2 b2) (timesFloat# a3 b3) (timesFloat# a4 b4)
    {-# INLINE (*) #-}

    negate (FloatX4# a1 a2 a3 a4) = FloatX4#
      (negateFloat# a1) (negateFloat# a2) (negateFloat# a3) (negateFloat# a4)
    {-# INLINE negate #-}

    abs (FloatX4# a1 a2 a3 a4)
      = FloatX4#
      (if isTrue# (a1 `geFloat#` 0.0#) then a1 else negateFloat# a1)
      (if isTrue# (a2 `geFloat#` 0.0#) then a2 else negateFloat# a2)
      (if isTrue# (a3 `geFloat#` 0.0#) then a3 else negateFloat# a3)
      (if isTrue# (a4 `geFloat#` 0.0#) then a4 else negateFloat# a4)
    {-# INLINE abs #-}

    signum (FloatX4# a1 a2 a3 a4)
      = FloatX4# (if isTrue# (a1 `gtFloat#` 0.0#)
                  then 1.0#
                  else if isTrue# (a1 `ltFloat#` 0.0#) then -1.0# else 0.0# )
                 (if isTrue# (a2 `gtFloat#` 0.0#)
                  then 1.0#
                  else if isTrue# (a2 `ltFloat#` 0.0#) then -1.0# else 0.0# )
                 (if isTrue# (a3 `gtFloat#` 0.0#)
                  then 1.0#
                  else if isTrue# (a3 `ltFloat#` 0.0#) then -1.0# else 0.0# )
                 (if isTrue# (a4 `gtFloat#` 0.0#)
                  then 1.0#
                  else if isTrue# (a4 `ltFloat#` 0.0#) then -1.0# else 0.0# )
    {-# INLINE signum #-}

    fromInteger n = case fromInteger n of F# x -> FloatX4# x x x x
    {-# INLINE fromInteger #-}



instance Fractional (FloatX4 k) where

    FloatX4# a1 a2 a3 a4 / FloatX4# b1 b2 b3 b4 = FloatX4#
      (divideFloat# a1 b1) (divideFloat# a2 b2) (divideFloat# a3 b3) (divideFloat# a4 b4)
    {-# INLINE (/) #-}

    recip (FloatX4# a1 a2 a3 a4) = FloatX4#
      (divideFloat# 1.0# a1) (divideFloat# 1.0# a2) (divideFloat# 1.0# a3) (divideFloat# 1.0# a4)
    {-# INLINE recip #-}

    fromRational r = case fromRational r of F# x -> FloatX4# x x x x
    {-# INLINE fromRational #-}



instance Floating (FloatX4 k) where

    pi = FloatX4#
      3.141592653589793238#
      3.141592653589793238#
      3.141592653589793238#
      3.141592653589793238#
    {-# INLINE pi #-}

    exp (FloatX4# a1 a2 a3 a4) = FloatX4#
      (expFloat# a1) (expFloat# a2) (expFloat# a3) (expFloat# a4)
    {-# INLINE exp #-}

    log (FloatX4# a1 a2 a3 a4) = FloatX4#
      (logFloat# a1) (logFloat# a2) (logFloat# a3) (logFloat# a4)
    {-# INLINE log #-}

    sqrt (FloatX4# a1 a2 a3 a4) = FloatX4#
      (sqrtFloat# a1) (sqrtFloat# a2) (sqrtFloat# a3) (sqrtFloat# a4)
    {-# INLINE sqrt #-}

    sin (FloatX4# a1 a2 a3 a4) = FloatX4#
      (sinFloat# a1) (sinFloat# a2) (sinFloat# a3) (sinFloat# a4)
    {-# INLINE sin #-}

    cos (FloatX4# a1 a2 a3 a4) = FloatX4#
      (cosFloat# a1) (cosFloat# a2) (cosFloat# a3) (cosFloat# a4)
    {-# INLINE cos #-}

    tan (FloatX4# a1 a2 a3 a4) = FloatX4#
      (tanFloat# a1) (tanFloat# a2) (tanFloat# a3) (tanFloat# a4)
    {-# INLINE tan #-}

    asin (FloatX4# a1 a2 a3 a4) = FloatX4#
      (asinFloat# a1) (asinFloat# a2) (asinFloat# a3) (asinFloat# a4)
    {-# INLINE asin #-}

    acos (FloatX4# a1 a2 a3 a4) = FloatX4#
      (acosFloat# a1) (acosFloat# a2) (acosFloat# a3) (acosFloat# a4)
    {-# INLINE acos #-}

    atan (FloatX4# a1 a2 a3 a4) = FloatX4#
      (atanFloat# a1) (atanFloat# a2) (atanFloat# a3) (atanFloat# a4)
    {-# INLINE atan #-}

    sinh (FloatX4# a1 a2 a3 a4) = FloatX4#
      (sinhFloat# a1) (sinhFloat# a2) (sinhFloat# a3) (sinhFloat# a4)
    {-# INLINE sinh #-}

    cosh (FloatX4# a1 a2 a3 a4) = FloatX4#
      (coshFloat# a1) (coshFloat# a2) (coshFloat# a3) (coshFloat# a4)
    {-# INLINE cosh #-}

    tanh (FloatX4# a1 a2 a3 a4) = FloatX4#
      (tanhFloat# a1) (tanhFloat# a2) (tanhFloat# a3) (tanhFloat# a4)
    {-# INLINE tanh #-}

    FloatX4# a1 a2 a3 a4 ** FloatX4# b1 b2 b3 b4 = FloatX4#
      (powerFloat# a1 b1) (powerFloat# a2 b2) (powerFloat# a3 b3) (powerFloat# a4 b4)
    {-# INLINE (**) #-}

    logBase x y         =  log y / log x
    {-# INLINE logBase #-}

    asinh x = log (x + sqrt (1.0+x*x))
    {-# INLINE asinh #-}

    acosh x = log (x + (x+1.0) * sqrt ((x-1.0)/(x+1.0)))
    {-# INLINE acosh #-}

    atanh x = 0.5 * log ((1.0+x) / (1.0-x))
    {-# INLINE atanh #-}




instance PrimBytes (FloatX4 k) where

    getBytes (FloatX4# a1 a2 a3 a4) = case runRW#
       ( \s0 -> case newByteArray# (byteSize @Float undefined *# 4#) s0 of
           (# s1, marr #) -> case writeFloatArray# marr 0# a1 s1 of
             s2 -> case writeFloatArray# marr 1# a2 s2 of
               s3 -> case writeFloatArray# marr 2# a3 s3 of
                 s4 -> case writeFloatArray# marr 3# a4 s4 of
                   s5 -> unsafeFreezeByteArray# marr s5
       ) of (# _, a #) -> a
    {-# INLINE getBytes #-}

    fromBytes off arr
      | i <- uncheckedIShiftRL# off 3#
      = FloatX4#
      (indexFloatArray# arr i)
      (indexFloatArray# arr (i +# 1#))
      (indexFloatArray# arr (i +# 2#))
      (indexFloatArray# arr (i +# 3#))
    {-# INLINE fromBytes #-}

    readBytes mba off s0
      | i <- uncheckedIShiftRL# off 3#
      = case readFloatArray# mba i s0 of
      (# s1, a1 #) -> case readFloatArray# mba (i +# 1#) s1 of
        (# s2, a2 #) -> case readFloatArray# mba (i +# 2#) s2 of
          (# s3, a3 #) -> case readFloatArray# mba (i +# 3#) s3 of
            (# s4, a4 #) -> (# s4, FloatX4# a1 a2 a3 a4 #)
    {-# INLINE readBytes #-}

    writeBytes mba off (FloatX4# a1 a2 a3 a4) s
      | i <- uncheckedIShiftRL# off 3#
      = writeFloatArray# mba (i +# 3#) a4
      ( writeFloatArray# mba (i +# 2#) a3
      ( writeFloatArray# mba (i +# 1#) a2
      ( writeFloatArray# mba  i        a1 s )))
    {-# INLINE writeBytes #-}


    byteSize _ = byteSize @Float undefined *# 4#
    {-# INLINE byteSize #-}

    byteAlign _ = byteAlign @Float undefined *# 4#
    {-# INLINE byteAlign #-}

    byteOffset _ = 0#
    {-# INLINE byteOffset #-}

    indexArray ba off
      | i <- uncheckedIShiftL# off 2#
      = FloatX4#
      (indexFloatArray# ba i)
      (indexFloatArray# ba (i +# 1#))
      (indexFloatArray# ba (i +# 2#))
      (indexFloatArray# ba (i +# 3#))
    {-# INLINE indexArray #-}

    readArray mba off s0
      | i <- uncheckedIShiftL# off 2#
      = case readFloatArray# mba i s0 of
      (# s1, a1 #) -> case readFloatArray# mba (i +# 1#) s1 of
        (# s2, a2 #) -> case readFloatArray# mba (i +# 2#) s2 of
          (# s3, a3 #) -> case readFloatArray# mba (i +# 3#) s3 of
            (# s4, a4 #) -> (# s4, FloatX4# a1 a2 a3 a4 #)
    {-# INLINE readArray #-}

    writeArray mba off (FloatX4# a1 a2 a3 a4) s
      | i <- uncheckedIShiftL# off 2#
      = writeFloatArray# mba (i +# 3#) a4
      ( writeFloatArray# mba (i +# 2#) a3
      ( writeFloatArray# mba (i +# 1#) a2
      ( writeFloatArray# mba  i        a1 s )))
    {-# INLINE writeArray #-}


instance PrimArray Float (FloatX4 k) where

    broadcast (F# x) = FloatX4# x x x x
    {-# INLINE broadcast #-}

    ix# 0# (FloatX4# a1 _ _ _) = F# a1
    ix# 1# (FloatX4# _ a2 _ _) = F# a2
    ix# 2# (FloatX4# _ _ a3 _) = F# a3
    ix# 3# (FloatX4# _ _ _ a4) = F# a4
    ix# _   _                   = undefined
    {-# INLINE ix# #-}

    gen# _ f s0 = case f s0 of
      (# s1, F# a1 #) -> case f s1 of
        (# s2, F# a2 #) -> case f s2 of
          (# s3, F# a3 #) -> case f s3 of
            (# s4, F# a4 #) -> (# s4, FloatX4# a1 a2 a3 a4 #)


    upd# _ 0# (F# q) (FloatX4# _ y z w) = FloatX4# q y z w
    upd# _ 1# (F# q) (FloatX4# x _ z w) = FloatX4# x q z w
    upd# _ 2# (F# q) (FloatX4# x y _ w) = FloatX4# x y q w
    upd# _ 3# (F# q) (FloatX4# x y z _) = FloatX4# x y z q
    upd# _ _ _ x                         = x
    {-# INLINE upd# #-}

    elemOffset _ = 0#
    {-# INLINE elemOffset #-}

    elemSize0 _  = 4#
    {-# INLINE elemSize0 #-}

    fromElems off _ ba = FloatX4#
      (indexFloatArray# ba off)
      (indexFloatArray# ba (off +# 1#))
      (indexFloatArray# ba (off +# 2#))
      (indexFloatArray# ba (off +# 3#))
    {-# INLINE fromElems #-}
