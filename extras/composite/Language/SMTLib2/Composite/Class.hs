module Language.SMTLib2.Composite.Class where

import Language.SMTLib2
import Language.SMTLib2.Composite.Lens

import Data.GADT.Compare
import Data.GADT.Show
import Data.Proxy
import Data.Functor.Identity
import Control.Monad.Writer
import Control.Lens

type CompDescr arg = arg Repr

-- | A composite is a data-structure composed of multiple SMT expressions.
class (GCompare (RevComp arg),GShow (RevComp arg))
      => Composite (arg :: (Type -> *) -> *) where
  type RevComp arg :: Type -> *
  foldExprs :: (Monad m,GetType e)
            => (forall t. RevComp arg t -> e t -> m (e' t))
            -> arg e
            -> m (arg e')
  accessComposite :: GetType e => RevComp arg t -> MaybeLens (arg e) (e t)
  compCombine :: (Embed m e,Monad m,GetType e,GCompare e)
              => (forall tp. e tp -> e tp -> m (e tp))
              -> arg e -> arg e -> m (Maybe (arg e))

  revName :: Proxy arg -> RevComp arg tp -> String
  revName _ _ = "rev"
  compCompare :: GCompare e => arg e -> arg e -> Ordering
  compShow :: GShow e => Int -> arg e -> ShowS

  compInvariant :: (Embed m e,Monad m) => arg e -> m [e BoolType]
  compInvariant _ = return []

{-

XXX: These overlap

instance (Composite arg,GCompare e) => Eq (arg e) where
  (==) x y = compCompare x y == EQ

instance (Composite arg,GCompare e) => Ord (arg e) where
  compare = compCompare

instance (Composite arg,GShow e) => Show (arg e) where
  showsPrec = compShow -}

unionDescr :: Composite arg => arg Repr -> arg Repr -> Maybe (arg Repr)
unionDescr x y = runIdentity $ compCombine (\tp _ -> return tp) x y

compITE :: Composite arg => (Embed m e,Monad m,GetType e,GCompare e) => e BoolType -> arg e -> arg e -> m (Maybe (arg e))
compITE cond = compCombine (ite cond)

compType :: (Composite arg,GetType e) => arg e -> arg Repr
compType = runIdentity . foldExprs (const $ return . getType)

createComposite :: (Composite arg,Monad m)
                => (forall t. Repr t -> RevComp arg t -> m (e t))
                -> CompDescr arg
                -> m (arg e)
createComposite f descr
  = foldExprs (\rev tp -> f tp rev) descr

revType :: Composite arg => CompDescr arg -> RevComp arg tp -> Repr tp
revType descr rev = case descr `getMaybe` accessComposite rev of
  Just r -> r
  Nothing -> error "revType: Internal error, type for unknown element requested."

class Composite arg => CompositeExtract arg where
  type CompExtract arg
  compExtract :: (Embed m e,Monad m,GetType e) => (forall tp. e tp -> m (Value tp)) -> arg e -> m (CompExtract arg)

defaultUnion :: (Composite arg,Monad m,GetType a,GetType b)
             => (forall t. RevComp arg t -> Maybe (a t) -> Maybe (b t) -> m (c t))
             -> CompDescr arg
             -> arg a
             -> arg b
             -> m (arg c)
defaultUnion f descr x y
  = createComposite (\_ rev -> f rev (x `getMaybe` accessComposite rev) (y `getMaybe` accessComposite rev)) descr

defaultEq :: (Composite arg,Embed m e,Monad m,GetType e)
          => CompDescr arg
          -> arg e
          -> arg e
          -> m (e BoolType)
defaultEq descr x y = do
  eqs <- execWriterT $ defaultUnion (\_ -> comb) descr x y
  case eqs of
    [] -> true
    [x] -> return x
    _ -> and' eqs
  where
    comb Nothing Nothing = return undefined
    comb (Just x) (Just y) = do
      eq <- lift $ x .==. y
      tell [eq]
      return undefined
    comb _ _ = do
      f <- lift false
      tell [f]
      return undefined
