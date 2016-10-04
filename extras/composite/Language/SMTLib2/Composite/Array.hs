module Language.SMTLib2.Composite.Array where

import Language.SMTLib2 hiding (select,store)
import qualified Language.SMTLib2 as SMT
import Language.SMTLib2.Composite.Class hiding (defaultEq)
import Language.SMTLib2.Composite.Lens
import Language.SMTLib2.Composite.Domains
import Language.SMTLib2.Internals.Type (Lifted,Fst,Snd)
import Language.SMTLib2.Internals.Embed
import Language.SMTLib2.Internals.Expression as E
import qualified Language.SMTLib2.Internals.Type.List as List

import Data.GADT.Show
import Data.GADT.Compare
import Data.Functor.Identity
import Control.Monad.Reader
import Control.Monad.Except
import Control.Monad.State
import Control.Lens hiding (Const)

newtype Arrayed idx e tp = Arrayed { _arrayed :: e (ArrayType idx tp) }

makeLenses ''Arrayed

data CompArray idx c e = CompArray { _indexDescr :: List Repr idx
                                   , _compArray  :: c (Arrayed idx e) }

makeLenses ''CompArray

data RevArray idx c tp where
  RevArray :: RevComp c tp -> RevArray idx c (ArrayType idx tp)

arrayDescr :: Composite c => List Repr idx -> CompDescr c -> CompDescr (CompArray idx c)
arrayDescr idx el = CompArray idx $ runIdentity $ foldExprs (\_ tp -> return $ Arrayed (array idx tp)) el

elementDescr :: Composite c => CompArray idx c Repr -> c Repr
elementDescr (CompArray _ arr) = runIdentity $ foldExprs (\_ (Arrayed (ArrayRepr _ tp)) -> return tp) arr

instance GEq e => Eq (Arrayed idx e tp) where
  (==) (Arrayed x) (Arrayed y) = defaultEq x y

instance GCompare e => Ord (Arrayed idx e tp) where
  compare (Arrayed x) (Arrayed y) = defaultCompare x y

instance GShow e => Show (Arrayed idx e tp) where
  showsPrec p (Arrayed x) = gshowsPrec p x

instance GetType e => GetType (Arrayed i e) where
  getType (Arrayed e) = case getType e of
    ArrayRepr _ tp -> tp

instance GEq e => GEq (Arrayed idx e) where
  geq (Arrayed x) (Arrayed y) = do
    Refl <- geq x y
    return Refl

instance GCompare e => GCompare (Arrayed idx e) where
  gcompare (Arrayed x) (Arrayed y) = case gcompare x y of
    GEQ -> GEQ
    GLT -> GLT
    GGT -> GGT

instance GShow e => GShow (Arrayed idx e) where
  gshowsPrec p (Arrayed x) = gshowsPrec p x

instance Composite c => Composite (CompArray i c) where
  type RevComp (CompArray i c) = RevArray i c
  foldExprs f (CompArray idx c) = do
    nc <- foldExprs (\r (Arrayed e) -> do
                        ne <- f (RevArray r) e
                        return (Arrayed ne)
                    ) c
    return (CompArray idx nc)
  accessComposite (RevArray r)
    = maybeLens compArray `composeMaybe`
      accessComposite r `composeMaybe`
      maybeLens arrayed
  compCombine f (CompArray idx arr1) (CompArray _ arr2) = do
    narr <- runReaderT (compCombine (\(Arrayed e1) (Arrayed e2) -> do
                                        ne <- lift $ f e1 e2
                                        return (Arrayed ne)
                                    ) arr1 arr2
                       ) idx
    return $ fmap (CompArray idx) narr
  compCompare (CompArray _ arr1) (CompArray _ arr2)
    = compCompare arr1 arr2
  compShow p (CompArray _ arr) = compShow p arr
  compInvariant (CompArray idx arr) = do
    invarr <- runReaderT (compInvariant arr) idx
    mapM (\(Arrayed x) -> x .==. constArray idx true) invarr

instance Composite c => Show (RevArray i c tp) where
  showsPrec p (RevArray r) = showParen (p>10) $
    showString "arr " . gshowsPrec 11 r

instance Composite c => GShow (RevArray i c) where
  gshowsPrec = showsPrec

instance Composite c => GEq (RevArray i c) where
  geq (RevArray r1) (RevArray r2) = do
    Refl <- geq r1 r2
    return Refl

instance Composite c => GCompare (RevArray i c) where
  gcompare (RevArray r1) (RevArray r2) = case gcompare r1 r2 of
    GEQ -> GEQ
    GLT -> GLT
    GGT -> GGT

instance Composite c => Container (CompArray idx c) where
  type ElementType (CompArray idx c) = c
  elementType = elementDescr

instance (Composite c,IsSingleton idx,SingletonType idx ~ i) => IsArray (CompArray '[i] c) idx where
  newArray idx el = do
    let ridx = runIdentity (getSingleton idx) ::: Nil
    newConstantArray ridx el
  select (CompArray _ arr) idx = do
    ridx <- getSingleton idx
    el <- foldExprs (\_ (Arrayed e) -> SMT.select e (ridx ::: Nil)) arr
    return (Just el)
  store arr idx el = do
    ridx <- getSingleton idx
    storeArray arr (ridx ::: Nil) el

newConstantArray :: (Composite el,Embed m e,Monad m,GetType e) => List Repr idx -> el e -> m (CompArray idx el e)
newConstantArray idx el = do
  arr <- foldExprs (\_ e -> do
                       ne <- constArray idx e
                       return $ Arrayed ne
                   ) el
  return $ CompArray idx arr

selectArray :: (Composite c,Embed m e,Monad m,GetType e) => CompArray i c e -> List e i -> m (c e)
selectArray (CompArray _ c) i = foldExprs (\_ (Arrayed e) -> SMT.select e i) c

storeArray :: (Composite c,Embed m e,Monad m,GetType e) => CompArray i c e -> List e i -> c e -> m (Maybe (CompArray i c e))
storeArray (CompArray idx arr) i el = do
  narr <- runExceptT $ execStateT
          (foldExprs
            (\rev e -> do
                arr <- get
                case arr `getMaybe` accessComposite rev of
                  Just (Arrayed carr) -> do
                    narr <- lift $ lift $ SMT.store carr i e
                    case setMaybe arr (accessComposite rev) (Arrayed narr) of
                      Just res -> do
                        put res
                        return e
                      Nothing -> throwError ()
                  Nothing -> do
                    narr <- lift $ lift $ SMT.constArray idx e
                    case setMaybe arr (accessComposite rev) (Arrayed narr) of
                      Just res -> do
                        put res
                        return e
                      Nothing -> throwError ()
            ) el) arr
  case narr of
      Left () -> return Nothing
      Right narr' -> return $ Just $ CompArray idx narr'

arrayElement :: Composite c => (forall m e. (Embed m e,Monad m,GetType e) => m (List e idx)) -> CompLens (CompArray idx c) c
arrayElement idx = lensM (\arr -> do
                             ridx <- idx
                             selectArray arr ridx
                         )
                   (\arr el -> do
                       ridx <- idx
                       res <- storeArray arr ridx el
                       case res of
                         Just r -> return r)
  where
    arrayedElementType :: Arrayed idx Repr tp -> Repr tp
    arrayedElementType (Arrayed (ArrayRepr _ tp)) = tp

    elementType :: Composite c => CompArray idx c Repr -> c Repr
    elementType (CompArray idx arr) = runIdentity $ foldExprs (\_ -> return . arrayedElementType) arr

instance (Embed m e,Monad m) => Embed (ReaderT (List Repr idx) m) (Arrayed idx e) where
  type EmVar (ReaderT (List Repr idx) m) (Arrayed idx e) = Arrayed idx (EmVar m e)
  type EmQVar (ReaderT (List Repr idx) m) (Arrayed idx e) = Arrayed idx (EmQVar m e)
  type EmFun (ReaderT (List Repr idx) m) (Arrayed idx e) = EmFun m e
  type EmFunArg (ReaderT (List Repr idx) m) (Arrayed idx e) = Arrayed idx (EmFunArg m e)
  type EmLVar (ReaderT (List Repr idx) m) (Arrayed idx e) = Arrayed idx (EmLVar m e)
  embed e = do
    re <- e
    case re of
      Var (Arrayed x) -> fmap Arrayed $ lift $ embed $ pure $ Var x
      QVar (Arrayed x) -> fmap Arrayed $ lift $ embed $ pure $ QVar x
      FVar (Arrayed x) -> fmap Arrayed $ lift $ embed $ pure $ FVar x
      LVar (Arrayed x) -> fmap Arrayed $ lift $ embed $ pure $ LVar x
      App f args -> do
        idx <- ask
        fmap Arrayed $ lift $ embed $ pure $ App (E.Map idx f) (mapArgs args)
      Const x -> do
        idx <- ask
        tp <- lift embedTypeOf
        ex <- lift $ embed $ pure $ Const x
        arr <- lift $ embed $ pure $ App (E.ConstArray idx (tp ex)) (ex ::: Nil)
        return $ Arrayed arr
      AsArray f -> do
        idx <- ask
        tp <- lift embedTypeOf
        arr <- lift $ embed $ pure $ AsArray f
        narr <- lift $ embed $ pure $ App (E.ConstArray idx (tp arr)) (arr ::: Nil)
        return $ Arrayed narr
      Quantification _ _ _ -> error "Cannot embed quantification in Arrayed"
      Let bnd (Arrayed body) -> fmap Arrayed $ lift $ embed $ pure $ Let (mapLets bnd) body
    where
      mapArgs :: List (Arrayed idx e) tps
              -> List e (Lifted tps idx)
      mapArgs Nil = Nil
      mapArgs ((Arrayed x) ::: xs) = x ::: mapArgs xs

      mapLets :: List (LetBinding (Arrayed idx lvar) (Arrayed idx e)) tps
              -> List (LetBinding lvar e) (Lifted tps idx)
      mapLets Nil = Nil
      mapLets (LetBinding (Arrayed q) (Arrayed e) ::: xs)
        = LetBinding q e ::: mapLets xs
  embedTypeOf = do
    tp <- lift embedTypeOf
    let f (Arrayed (tp -> ArrayRepr _ rtp)) = rtp
    return f