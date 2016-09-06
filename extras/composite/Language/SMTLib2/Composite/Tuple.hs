module Language.SMTLib2.Composite.Tuple where

import Language.SMTLib2
import Language.SMTLib2.Composite.Class
import Language.SMTLib2.Composite.Lens

import Data.GADT.Show
import Data.GADT.Compare
import Data.Proxy
import Control.Lens

data CompTuple2 (a :: (Type -> *) -> *) (b :: (Type -> *) -> *) e
  = CompTuple2 { _ctuple2_1 :: a e
               , _ctuple2_2 :: b e }

data CompTuple3 (a :: (Type -> *) -> *) (b :: (Type -> *) -> *) (c :: (Type -> *) -> *) e
  = CompTuple3 { _ctuple3_1 :: a e
               , _ctuple3_2 :: b e
               , _ctuple3_3 :: c e }

data RevTuple2 a b tp
  = RevTuple2_1 (RevComp a tp)
  | RevTuple2_2 (RevComp b tp)

data RevTuple3 a b c tp
  = RevTuple3_1 (RevComp a tp)
  | RevTuple3_2 (RevComp b tp)
  | RevTuple3_3 (RevComp c tp)

makeLenses ''CompTuple2
makeLenses ''CompTuple3

tuple2_1 :: (Composite a,Composite b) => CompLens (CompTuple2 a b) a
tuple2_1 = liftLens ctuple2_1

tuple2_2 :: (Composite a,Composite b) => CompLens (CompTuple2 a b) b
tuple2_2 = liftLens ctuple2_2

tuple3_1 :: (Composite a,Composite b,Composite c) => CompLens (CompTuple3 a b c) a
tuple3_1 = liftLens ctuple3_1

tuple3_2 :: (Composite a,Composite b,Composite c) => CompLens (CompTuple3 a b c) b
tuple3_2 = liftLens ctuple3_2

tuple3_3 :: (Composite a,Composite b,Composite c) => CompLens (CompTuple3 a b c) c
tuple3_3 = liftLens ctuple3_3

instance (Composite a,Composite b) => Composite (CompTuple2 a b) where
  type RevComp (CompTuple2 a b) = RevTuple2 a b
  foldExprs f tup = do
    n1 <- foldExprs (f . RevTuple2_1) (_ctuple2_1 tup)
    n2 <- foldExprs (f . RevTuple2_2) (_ctuple2_2 tup)
    return $ CompTuple2 n1 n2
  accessComposite (RevTuple2_1 r) = maybeLens ctuple2_1 `composeMaybe` accessComposite r
  accessComposite (RevTuple2_2 r) = maybeLens ctuple2_2 `composeMaybe` accessComposite r
  compCombine f (CompTuple2 x1 y1) (CompTuple2 x2 y2) = do
    actX <- compCombine f x1 x2
    actY <- compCombine f y1 y2
    return $ do
      x3 <- actX
      y3 <- actY
      return $ CompTuple2 x3 y3
  compCompare (CompTuple2 x1 y1) (CompTuple2 x2 y2) = case compCompare x1 x2 of
    EQ -> compCompare y1 y2
    r -> r
  compShow p (CompTuple2 x y) = showChar '(' . compShow 0 x . showChar ',' . compShow 0 y . showChar ')'
  compInvariant (CompTuple2 x y) = do
    invX <- compInvariant x
    invY <- compInvariant y
    return $ invX++invY

instance (CompositeExtract a,CompositeExtract b)
  => CompositeExtract (CompTuple2 a b) where
  type CompExtract (CompTuple2 a b) = (CompExtract a,CompExtract b)
  compExtract f (CompTuple2 a b)
    = (\va vb -> (va,vb)) <$>
      compExtract f a <*>
      compExtract f b

instance (Composite a,Composite b,Composite c) => Composite (CompTuple3 a b c) where
  type RevComp (CompTuple3 a b c) = RevTuple3 a b c
  foldExprs f tup = do
    n1 <- foldExprs (f . RevTuple3_1) (_ctuple3_1 tup)
    n2 <- foldExprs (f . RevTuple3_2) (_ctuple3_2 tup)
    n3 <- foldExprs (f . RevTuple3_3) (_ctuple3_3 tup)
    return $ CompTuple3 n1 n2 n3
  accessComposite (RevTuple3_1 r) = maybeLens ctuple3_1 `composeMaybe` accessComposite r
  accessComposite (RevTuple3_2 r) = maybeLens ctuple3_2 `composeMaybe` accessComposite r
  accessComposite (RevTuple3_3 r) = maybeLens ctuple3_3 `composeMaybe` accessComposite r
  compCombine f (CompTuple3 x1 y1 z1) (CompTuple3 x2 y2 z2) = do
    actX <- compCombine f x1 x2
    actY <- compCombine f y1 y2
    actZ <- compCombine f z1 z2
    return $ do
      x3 <- actX
      y3 <- actY
      z3 <- actZ
      return $ CompTuple3 x3 y3 z3
  compCompare (CompTuple3 x1 y1 z1) (CompTuple3 x2 y2 z2) = case compCompare x1 x2 of
    EQ -> case compCompare y1 y2 of
      EQ -> compCompare z1 z2
      r -> r
    r -> r
  compShow _ (CompTuple3 x y z)
    = showChar '(' .
      compShow 0 x . showChar ',' .
      compShow 0 y . showChar ',' .
      compShow 0 z . showChar ')'
  compInvariant (CompTuple3 x y z) = do
    invX <- compInvariant x
    invY <- compInvariant y
    invZ <- compInvariant z
    return $ invX++invY++invZ

instance (CompositeExtract a,CompositeExtract b,CompositeExtract c)
  => CompositeExtract (CompTuple3 a b c) where
  type CompExtract (CompTuple3 a b c) = (CompExtract a,CompExtract b,CompExtract c)
  compExtract f (CompTuple3 a b c) = do
    va <- compExtract f a
    vb <- compExtract f b
    vc <- compExtract f c
    return (va,vb,vc)

instance (Composite a,Composite b) => Show (RevTuple2 a b tp) where
  showsPrec p (RevTuple2_1 r) = showParen (p>10) $
    showString "[1/2] " .
    gshowsPrec 0 r
  showsPrec p (RevTuple2_2 r) = showParen (p>10) $
    showString "[2/2] " .
    gshowsPrec 0 r

instance (Composite a,Composite b,Composite c) => Show (RevTuple3 a b c tp) where
  showsPrec p (RevTuple3_1 r) = showParen (p>10) $
    showString "[1/3] " .
    gshowsPrec 0 r
  showsPrec p (RevTuple3_2 r) = showParen (p>10) $
    showString "[2/3] " .
    gshowsPrec 0 r
  showsPrec p (RevTuple3_3 r) = showParen (p>10) $
    showString "[3/3] " .
    gshowsPrec 0 r

instance (Composite a,Composite b) => GShow (RevTuple2 a b) where
  gshowsPrec = showsPrec

instance (Composite a,Composite b,Composite c) => GShow (RevTuple3 a b c) where
  gshowsPrec = showsPrec

instance (Composite a,Composite b) => GEq (RevTuple2 a b) where
  geq (RevTuple2_1 r1) (RevTuple2_1 r2) = do
    Refl <- geq r1 r2
    return Refl
  geq (RevTuple2_2 r1) (RevTuple2_2 r2) = do
    Refl <- geq r1 r2
    return Refl
  geq _ _ = Nothing

instance (Composite a,Composite b,Composite c) => GEq (RevTuple3 a b c) where
  geq (RevTuple3_1 r1) (RevTuple3_1 r2) = do
    Refl <- geq r1 r2
    return Refl
  geq (RevTuple3_2 r1) (RevTuple3_2 r2) = do
    Refl <- geq r1 r2
    return Refl
  geq (RevTuple3_3 r1) (RevTuple3_3 r2) = do
    Refl <- geq r1 r2
    return Refl
  geq _ _ = Nothing

instance (Composite a,Composite b) => GCompare (RevTuple2 a b) where
  gcompare (RevTuple2_1 r1) (RevTuple2_1 r2) = case gcompare r1 r2 of
    GEQ -> GEQ
    GLT -> GLT
    GGT -> GGT
  gcompare (RevTuple2_1 _) _ = GLT
  gcompare _ (RevTuple2_1 _) = GGT
  gcompare (RevTuple2_2 r1) (RevTuple2_2 r2) = case gcompare r1 r2 of
    GEQ -> GEQ
    GLT -> GLT
    GGT -> GGT

instance (Composite a,Composite b,Composite c) => GCompare (RevTuple3 a b c) where
  gcompare (RevTuple3_1 r1) (RevTuple3_1 r2) = case gcompare r1 r2 of
    GEQ -> GEQ
    GLT -> GLT
    GGT -> GGT
  gcompare (RevTuple3_1 _) _ = GLT
  gcompare _ (RevTuple3_1 _) = GGT
  gcompare (RevTuple3_2 r1) (RevTuple3_2 r2) = case gcompare r1 r2 of
    GEQ -> GEQ
    GLT -> GLT
    GGT -> GGT
  gcompare (RevTuple3_2 _) _ = GLT
  gcompare _ (RevTuple3_2 _) = GGT
  gcompare (RevTuple3_3 r1) (RevTuple3_3 r2) = case gcompare r1 r2 of
    GEQ -> GEQ
    GLT -> GLT
    GGT -> GGT
