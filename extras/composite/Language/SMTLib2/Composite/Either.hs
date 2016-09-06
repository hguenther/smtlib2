module Language.SMTLib2.Composite.Either where

import Language.SMTLib2
import Language.SMTLib2.Composite.Class
import Language.SMTLib2.Composite.Lens

import Data.GADT.Show
import Data.GADT.Compare
import Control.Lens

newtype CompEither a b (e :: Type -> *) = CompEither { compEither :: Either (a e) (b e) }

data RevEither a b tp = RevLeft (RevComp a tp)
                      | RevRight (RevComp b tp)

left :: MaybeLens (CompEither a b e) (a e)
left = lens (\(CompEither x) -> case x of
                Left x' -> Just x'
                Right _ -> Nothing)
       (\x nel -> Just $ CompEither (Left nel))

right :: MaybeLens (CompEither a b e) (b e)
right = lens (\(CompEither x) -> case x of
                Right x' -> Just x'
                Left _ -> Nothing)
        (\x nel -> Just $ CompEither (Right nel))

instance (Composite a,Composite b) => Composite (CompEither a b) where
  type RevComp (CompEither a b) = RevEither a b
  foldExprs f (CompEither (Left x)) = do
    nx <- foldExprs (f . RevLeft) x
    return (CompEither (Left nx))
  foldExprs f (CompEither (Right x)) = do
    nx <- foldExprs (f . RevRight) x
    return (CompEither (Right nx))
  accessComposite (RevLeft r) = left `composeMaybe` accessComposite r
  accessComposite (RevRight r) = right `composeMaybe` accessComposite r
  compCombine f (CompEither (Left x)) (CompEither (Left y)) = do
    z <- compCombine f x y
    return $ fmap (CompEither . Left) z
  compCombine f (CompEither (Right x)) (CompEither (Right y)) = do
    z <- compCombine f x y
    return $ fmap (CompEither . Right) z
  compCombine _ _ _ = return Nothing
  compCompare (CompEither (Left x)) (CompEither (Left y)) = compCompare x y
  compCompare (CompEither (Left _)) _ = LT
  compCompare _ (CompEither (Left _)) = GT
  compCompare (CompEither (Right x)) (CompEither (Right y)) = compCompare x y
  compShow p (CompEither (Left x)) = showParen (p>10) $
    showString "Left " . compShow 11 x
  compShow p (CompEither (Right x)) = showParen (p>10) $
    showString "Right " . compShow 11 x
  compInvariant (CompEither (Left x)) = compInvariant x
  compInvariant (CompEither (Right x)) = compInvariant x
  
eitherDescr :: Either (CompDescr a) (CompDescr b) -> CompDescr (CompEither a b)
eitherDescr = CompEither

instance (CompositeExtract a,CompositeExtract b)
  => CompositeExtract (CompEither a b) where
  type CompExtract (CompEither a b) = Either (CompExtract a) (CompExtract b)
  compExtract f (CompEither v) = case v of
    Left l -> do
      res <- compExtract f l
      return (Left res)
    Right r -> do
      res <- compExtract f r
      return (Right res)

instance (Composite a,Composite b) => Show (RevEither a b tp) where
  showsPrec p (RevLeft r) = showParen (p>10) $
    showString "left " . gshowsPrec 11 r
  showsPrec p (RevRight r) = showParen (p>10) $
    showString "right " . gshowsPrec 11 r

instance (Composite a,Composite b) => GShow (RevEither a b) where
  gshowsPrec = showsPrec

instance (Composite a,Composite b) => GEq (RevEither a b) where
  geq (RevLeft x) (RevLeft y) = do
    Refl <- geq x y
    return Refl
  geq (RevRight x) (RevRight y) = do
    Refl <- geq x y
    return Refl
  geq _ _ = Nothing

instance (Composite a,Composite b) => GCompare (RevEither a b) where
  gcompare (RevLeft x) (RevLeft y) = case gcompare x y of
    GEQ -> GEQ
    GLT -> GLT
    GGT -> GGT
  gcompare (RevLeft _) _ = GLT
  gcompare _ (RevLeft _) = GGT
  gcompare (RevRight x) (RevRight y) = case gcompare x y of
    GEQ -> GEQ
    GLT -> GLT
    GGT -> GGT
