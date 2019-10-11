{-# LANGUAGE DataKinds                  #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE FunctionalDependencies     #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE OverloadedStrings          #-}

{-# OPTIONS_GHC -fno-warn-missing-local-signatures #-}

{-
Relation properties:

Reflexive: x ∘ x
    EQ, LE
Symmetric: x ∘ y ⇔ y ∘ x
    EQ, LE
Transitive: x ∘ y ⋀ y ∘ z ⇒ x ∘ z
    EQ, LE, LT, GT

Binary ops properties:

Commutative: x ∘ y == y ∘ x
  +, *, Max, Min
Associative: (x ∘ y) ∘ z == x ∘ (y ∘ z) == x ∘ y ∘ z
  +, *, Max, Min
Distributive: (f, ∘): f (x ∘ y) == f x ∘ f y
    (c*,+), (c*,-),
     ([ c*, c+, c^, c`Max`, c`Min`, Log2,
      , *c, +c, -c, ^c, `Max`c, `Min`c, `Div`c], [Max, Min]),

Other:
  a == b * Div a b + Mod a b
  a ^ (b * c) == (a ^ b) ^ c == a ^ b ^ c
  a ^ (b + c) == a^b * a^c
  x ^ 0 == 1
  0 ^ x == 0
  1 * x == x
  x * 1 == x
  x + 0 == x
  x - 0 == x
  0 + x == x
  a * a ^ b = a ^ (b + 1)
  a ^ b * a = a ^ (b + 1)
  a * a == a ^ 2
  a ^ x * b ^ x == (a * b) ^ x
  Log2 (2^x) == x
  c `Div` Max a b == Min (Div c a) (Div c b)
  c - Max a b == Min (c - a) (c - b)
  c `Div` Min a b == Max (Div c a) (Div c b)
  c - Min a b == Max (c - a) (c - b)

Show stoppers:
  Mod a 0
  Div a 0
  Log2 0

 -}
module Numeric.Dimensions.Plugin.SolveNat  where

import Data.Functor.Identity
import Data.String           (IsString)
import Outputable            hiding ((<>))

import Numeric.Dimensions.Plugin.AtLeast
import Numeric.Dimensions.Plugin.SolveNat.Exp
import Numeric.Dimensions.Plugin.SolveNat.NormalForm



data EqConstraint t v
  = CLT (Exp t v) (Exp t v)
    -- ^ @CmpNat a b ~ 'LT@
  | CEQ (Exp t v) (Exp t v)
    -- ^ @CmpNat a b ~ 'EQ@ or @a ~ b@
  | CGT (Exp t v) (Exp t v)
    -- ^ @CmpNat a b ~ 'GT@
  | CLE (Exp t v) (Exp t v)
    -- ^ @a <=? b ~ 'True@
  deriving (Eq, Ord, Show)

instance (Outputable v, Outputable t)
      => Outputable (EqConstraint t v) where
  ppr (CLT a b) = ppr a <+> "<" <+> ppr b
  ppr (CEQ a b) = ppr a <+> "~" <+> ppr b
  ppr (CGT a b) = ppr a <+> ">" <+> ppr b
  ppr (CLE a b) = ppr a <+> "<=" <+> ppr b

data SolveResult t v ct
  = Contradiction
    { solveRef  :: ct }
  | Success
    { solveRef  :: ct
    , solveDeps :: [EqConstraint t v]
    }
  deriving (Eq, Ord, Show)

instance (Outputable v, Outputable t, Outputable ct)
      => Outputable (SolveResult t v ct) where
  pprPrec p (Contradiction ct) = cparen (p > 10) $ "Contradiction" <+> pprPrec 10 ct
  pprPrec _ (Success ct ctx) = "Success" <+> braces
    ( pprWithCommas id ["solveRef =" <+> ppr ct, "solveDeps =" <+> ppr ctx])


-- | Derive all constraints that come out of the expression itself.
--   Do not simplify constraints yet.
implCts :: Exp t v -> [EqConstraint t v]
implCts (N _)     = mempty
implCts (F _)     = mempty
implCts (V _)     = mempty
implCts (a :+ b)  = implCts a <> implCts b
implCts (a :- b)  = [CLE b a] <> implCts a <> implCts b
implCts (a :* b)  = implCts a <> implCts b
implCts (a :^ b)  = implCts a <> implCts b
implCts (Div a b) = [CLE 0 b] <> implCts a <> implCts b
implCts (Mod a b) = [CLE 0 b] <> implCts a <> implCts b
implCts (Max a b) = implCts a <> implCts b
implCts (Min a b) = implCts a <> implCts b
implCts (Log2 a)  = [CGT a 0] <> implCts a


normalize :: (Ord v, Ord t) => Exp t v -> NormalE t v

normalize (N n)
  = minMax $ fromIntegral n
normalize (F t)
  = unit (UF t)
normalize (V v)
  = unit (UV v)

normalize (a :+ b)
  = map2Sums (+) (normalize a) (normalize b)

normalize (a :- b)
  = map2Sums (-) (normalize a) (inverseMM $ normalize b)

normalize (a :* b)
  = map2Sums (*) (normalize a) (normalize b)

normalize (a :^ b)
  = map2Sums powSums (normalize a) (normalize b)

normalize (Div a b)
  -- we can map over the first argument of the Dic but not second, because
  --  it would mess up mins, maxs and zeroes.
  =   foldr1 (map2Mins (<>))
    . fmap ( foldr1 (map2Maxs (<>))
           . fmap normDiv . getMaxsE)
    . getMinsE $ getNormalE $ normalize a
  where
    normDiv = flip normalizeDiv (getNormalE $ normalize b)

normalize (Mod a b)
  = normalizeMod (normalize a) (normalize b)

normalize (Max a b)
  = map2Maxs (<>) (normalize a) (normalize b)

normalize (Min a b)
  = map2Mins (<>) (normalize a) (normalize b)

normalize (Log2 a)
  = NormalE $ MinsE $ fmap normalizeLog2 $ getMinsE $ getNormalE $ normalize a


map2Mins :: (Ord v, Ord t)
         => (MinsE vl tl -> MinsE vr tr -> MinsE t v)
         -> NormalE vl tl -> NormalE vr tr -> NormalE t v
map2Mins k a = NormalE . k (getNormalE a) . getNormalE

map2Maxs :: (Ord v, Ord t)
         => (MaxsE vl tl -> MaxsE vr tr -> MaxsE t v)
         -> NormalE vl tl -> NormalE vr tr -> NormalE t v
map2Maxs k = map2Mins $ \a -> runIdentity . lift2Mins (\x -> pure . k x) a

map2Sums :: (Ord v, Ord t)
         => (SumsE None vl tl -> SumsE None vr tr -> SumsE None t v)
         -> NormalE vl tl -> NormalE vr tr -> NormalE t v
map2Sums k = map2Maxs $ \a -> runIdentity . lift2Maxs (\x -> pure . k x) a

lift2Maxs :: (Ord v, Ord t, Applicative m)
          => (SumsE None vl tl -> SumsE None vr tr -> m (SumsE None t v))
          -> MaxsE vl tl -> MaxsE vr tr
          -> m (MaxsE t v)
lift2Maxs f (MaxsE a)
  = fmap (MaxsE . flattenDesc) . traverse (\b -> traverse (`f` b) a) . getMaxsE

lift2Mins :: (Ord v, Ord t, Applicative m)
          => (MaxsE vl tl -> MaxsE vr tr -> m (MaxsE t v))
          -> MinsE vl tl -> MinsE vr tr
          -> m (MinsE t v)
lift2Mins f (MinsE a)
  = fmap (MinsE . flattenDesc) . traverse (\b -> traverse (`f` b) a) . getMinsE

-- | Swap Mins and Maxs and then renormalize according to the distributivity law.
--   Use this for 2nd argument of @Div@ or @(:-)@.
inverseMM :: (Ord v, Ord t) => NormalE t v -> NormalE t v
inverseMM (NormalE x) = NormalE (inverseMM' x)

inverseMM' :: (Ord v, Ord t) => MinsE t v -> MinsE t v
inverseMM' (MinsE (MaxsE xs :| L []))
    = MinsE $ (MaxsE . pure) <$> xs
inverseMM' (MinsE (maxs1 :| L (maxs2 : maxS)))
    = MinsE $ (<>) <$> a <*> b
  where
    MinsE a = inverseMM' $ MinsE $ pure maxs1
    MinsE b = inverseMM' $ MinsE $ maxs2 :| L maxS


normalizeDiv :: (Ord v, Ord t)
             => SumsE None t v -> MinsE t v -> NormalE t v
normalizeDiv a (MinsE bs)
  | isZero a  = minMax 0
    -- Note, I convert the minimum of a list of maximimums (MinsE bs) into
    -- the maximum of a list of sums, because bs is the second argument of Div,
    -- which means swapping MinsE-MaxsE
  | otherwise = foldr1 (map2Maxs (<>)) $ normalizeDiv' a <$> bs

normalizeDiv' :: (Ord v, Ord t)
              => SumsE None t v -> MaxsE t v -> NormalE t v
normalizeDiv' a b
  | (ca, SumsE (L [])) <- unconstSumsE a
  , (cb, True) <- foldr
      ( \x (cb, nothin) -> case unconstSumsE x of
                (cb', SumsE (L [])) -> (max cb cb', nothin)
                _                   -> (0, False)
      ) (0, True) $ getMaxsE b
  , cb /= 0   = minMax . fromInteger $ div ca cb
  | isOne  b  = minMax a
  | otherwise = unit $ UDiv a b


normalizeMod :: (Ord v, Ord t)
             => NormalE t v -> NormalE t v -> NormalE t v
normalizeMod (NormalE (MinsE (MaxsE (a :| L []) :| L [])))
             (NormalE (MinsE (MaxsE (b :| L []) :| L [])))
  | (ca, SumsE (L [])) <- unconstSumsE a
  , (cb, SumsE (L [])) <- unconstSumsE b
  , cb /= 0      = minMax $ fromInteger $ mod ca cb
normalizeMod a b
  | isZero a  = minMax 0
  | isOne  b  = minMax 0
  | otherwise = unit $ UMod a b

normalizeLog2 :: (Ord v, Ord t) => MaxsE t v -> MaxsE t v
normalizeLog2 p
  | (c, True) <- foldr
      ( \x (cb, nothin) -> case unconstSumsE x of
                (cb', SumsE (L [])) -> (max cb cb', nothin)
                _                   -> (0, False)
      ) (0, True) $ getMaxsE p
  , c > 0 = MaxsE . pure . fromIntegral $ log2Nat (fromInteger c)
  | otherwise = MaxsE . pure . unitAsSums $ ULog2 p



newtype Var = Var String
  deriving (Eq, Ord, IsString)

instance Show Var where
  show (Var x) = x

instance Outputable Var where
  ppr (Var x) = text x

newtype XType = XType String
  deriving (Eq, Ord, IsString)

instance Show XType where
  show (XType x) = x

instance Outputable XType where
  ppr (XType x) = text x

runSolveNat :: IO ()
runSolveNat = do
    putStrLn "Hello!"
    mapM_ (\e -> pprTraceM "implCts:   " $
                 ppr e $$ vcat (ppr <$> implCts e)) $ exprs
    mapM_ (\e ->
            let en = normalize e :: NormalE XType Var
                e' = fromNormal en
                eval1 = fmap toInteger
                      . evaluate $ runIdentity $ substituteVar mySubst e
                eval2 = fmap toInteger
                      . evaluate $ runIdentity $ substituteVar mySubst e'
            in  pprTraceM "normalize: "
                 $  ppr e
                 -- $$ pprNormalize (Var . show <$> en)
                 $$ ppr en
                 $$ ("validate:" <+> ppr (validate en))
                 $$ "eval orig:" <+> ppr eval1
                 $$ "eval norm:" <+> ppr eval2
          ) $ exprs
  where
    mySubst "x"  = pure $ N 17
    mySubst "y"  = pure $ N 9
    mySubst "z1" = pure $ N 256
    mySubst "z2" = pure $ N 1734
    mySubst "z3" = pure $ N 0
    mySubst v    = pure $ V v
    x = V "x" :: Exp XType Var
    y = V "y" :: Exp XType Var
    z1 = V "z1" :: Exp XType Var
    z2 = V "z2" :: Exp XType Var
    z3 = V "z3" :: Exp XType Var
    exprs :: [Exp XType Var]
    exprs =
      [ Log2 (Max 4 (Min (Div y x) (Mod (Max z1 3) 7)))
      , x + y + Min (Log2 z1) (Max 5 y)
      , x + y - Min (Log2 z1) (Max 5 y)
      , x * y + z1
      , x * ((y + z2) :^ z3) :^ z2 :^ 2
      , (z2 + z3 + (x * y - 7 * x)) :^ (z1 + 2)
      , F "Foo x z1 k" * x + 2 - y
      , 4 * 2 + 2 - 3:^2 + 19
      , 4 * 1 + 2 - 3:^2 + 19
      , 4 * 1 + 2 - (3:^2 + 1) + 19
      , 4 * 1 + (2 - 3:^2) + 19
      , 19 + (4 * 1 + 2 - 3:^2)
      , 4 * 1 + 2 - Log2 (3:^2) + 19
      , x + 3 + 3 + 5 - 3 + y * z1 + Max y (100 - x - 8 + z1 * 2)
          + Min (2 + Log2 y) (3 + Log2 (2 * x + Mod (5 + Min x 3) 7))
          + Div (9 - Max 6 3 + 2 * 2 :^ 3) (Log2 18 :^ 3)
      , x + 3 + 3 + 5 - 3 + y * z1 + Max y (100 - x - 8 + z1 * 2)
          + Min (2 + Log2 y) (3 - Log2 (2 * x + Mod (5 + Min x 3) 7))
          + Div (9 - Max 6 3 + 2 * 2 :^ 3) (Log2 18 :^ 3)
      , (x + y + 4) * (x - z1) + Max (x * (y + 2)) (y * (z1 + x)) - (x - z1) :^ 3
        + y :^ (z1 + 2)
      ]
