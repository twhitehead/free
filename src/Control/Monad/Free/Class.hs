{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Control.Monad.Free.Class
-- Copyright   :  (C) 2008-2011 Edward Kmett
-- License     :  BSD-style (see the file LICENSE)
--
-- Maintainer  :  Edward Kmett <ekmett@gmail.com>
-- Stability   :  experimental
-- Portability :  non-portable (fundeps, MPTCs)
--
-- Monads for free.
----------------------------------------------------------------------------
module Control.Monad.Free.Class
  ( MonadFree(..)
  ) where

import Control.Applicative
import Control.Monad.Trans.Reader
import qualified Control.Monad.Trans.State.Strict as Strict
import qualified Control.Monad.Trans.State.Lazy as Lazy
import qualified Control.Monad.Trans.Writer.Strict as Strict
import qualified Control.Monad.Trans.Writer.Lazy as Lazy
import qualified Control.Monad.Trans.RWS.Strict as Strict
import qualified Control.Monad.Trans.RWS.Lazy as Lazy
import Control.Monad.Trans.Cont
import Control.Monad.Trans.Maybe
import Control.Monad.Trans.List
import Control.Monad.Trans.Error
import Control.Monad.Trans.Identity
import Data.Monoid

-- |
-- Monads provide substitution ('fmap') and renormalization ('Control.Monad.join'):
--
-- @m '>>=' f = 'Control.Monad.join' . 'fmap' f m@
--
-- A free 'Monad' is one that does no work during the normalization step beyond simply grafting the two monadic values together.
--
-- @[]@ is not a free 'Monad' (in this sense) because @'Control.Monad.join' [[a]]@ smashes the lists flat.
--
-- On the other hand, consider:
--
-- @
-- data Tree a = Bin (Tree a) (Tree a) | Tip a
-- @
--
-- @
-- instance 'Monad' Tree where
--   'return' = Tip
--   Tip a '>>=' f = f a
--   Bin l r '>>=' f = Bin (l '>>=' f) (r '>>=' f)
-- @
--
-- This 'Monad' is the free 'Monad' of Pair:
--
-- @
-- data Pair a = Pair a a
-- @
--
-- And we could make an instance of 'MonadFree' for it directly:
--
-- @
-- instance 'MonadFree' Pair Tree where
--    'wrap' (Pair l r) = Bin l r
-- @
--
-- Or we could choose to program with @'Control.Monad.Free.Free' Pair@ instead of 'Tree'
-- and thereby avoid having to define our own 'Monad' instance.
--
-- Moreover, the @kan-extensions@ package provides 'MonadFree' instances that can
-- improve the /asymptotic/ complexity of code that constructors free monads by
-- effectively reassociating the use of ('>>=').
--
-- See 'Control.Monad.Free.Free' for a more formal definition of the free 'Monad'
-- for a 'Functor'.
class Monad m => MonadFree f m | m -> f where
  -- | Add a layer.
  wrap :: f (m a) -> m a

instance (Functor f, MonadFree f m) => MonadFree f (ReaderT e m) where
  wrap fm = ReaderT $ \e -> wrap $ flip runReaderT e <$> fm

instance (Functor f, MonadFree f m) => MonadFree f (Lazy.StateT s m) where
  wrap fm = Lazy.StateT $ \s -> wrap $ flip Lazy.runStateT s <$> fm

instance (Functor f, MonadFree f m) => MonadFree f (Strict.StateT s m) where
  wrap fm = Strict.StateT $ \s -> wrap $ flip Strict.runStateT s <$> fm

instance (Functor f, MonadFree f m) => MonadFree f (ContT r m) where
  wrap t = ContT $ \h -> wrap (fmap (\p -> runContT p h) t)

instance (Functor f, MonadFree f m, Monoid w) => MonadFree f (Lazy.WriterT w m) where
  wrap = Lazy.WriterT . wrap . fmap Lazy.runWriterT

instance (Functor f, MonadFree f m, Monoid w) => MonadFree f (Strict.WriterT w m) where
  wrap = Strict.WriterT . wrap . fmap Strict.runWriterT

instance (Functor f, MonadFree f m, Monoid w) => MonadFree f (Strict.RWST r w s m) where
  wrap fm = Strict.RWST $ \r s -> wrap $ fmap (\m -> Strict.runRWST m r s) fm

instance (Functor f, MonadFree f m, Monoid w) => MonadFree f (Lazy.RWST r w s m) where
  wrap fm = Lazy.RWST $ \r s -> wrap $ fmap (\m -> Lazy.runRWST m r s) fm

instance (Functor f, MonadFree f m) => MonadFree f (MaybeT m) where
  wrap = MaybeT . wrap . fmap runMaybeT

instance (Functor f, MonadFree f m) => MonadFree f (IdentityT m) where
  wrap = IdentityT . wrap . fmap runIdentityT

instance (Functor f, MonadFree f m) => MonadFree f (ListT m) where
  wrap = ListT . wrap . fmap runListT

instance (Functor f, MonadFree f m, Error e) => MonadFree f (ErrorT e m) where
  wrap = ErrorT . wrap . fmap runErrorT