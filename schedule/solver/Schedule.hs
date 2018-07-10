{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}

module Schedule where

import Control.Monad (MonadPlus(..), guard)
import Data.List (intersperse)

newtype Alternatives a = Alternatives { getAlternatives :: [a] }  

instance Show a => Show (Alternatives a) where
  show (Alternatives as) = concat $ intersperse " | " (map show as)

instance Monad Alternatives where
  return x = Alternatives [x]
  Alternatives [] >>= f = Alternatives []
  Alternatives (x:xs) >>= f = f x `app` (Alternatives xs >>= f) 
    where
      app (Alternatives xs) (Alternatives ys) = Alternatives (xs ++ ys)

instance MonadPlus Alternatives where
   mzero = Alternatives []
   (Alternatives xs) `mplus` (Alternatives ys) = Alternatives (xs ++ ys)

takeAlt :: Int -> Alternatives a -> Alternatives a
takeAlt n (Alternatives as) = Alternatives $ take n as


newtype Sequence a = Sequence { getSequence :: [a] } 
                  
instance Show a => Show (Sequence a) where
  show (Sequence as) = "{" ++ (concat $ intersperse ", " (map show as)) ++ "}"
                  

-- schedule algorithm (naive)

class Generator a b | a -> b where
  generate :: a -> Alternatives b

class Validator a where
  conflict :: a -> a -> Bool
  isValid :: Sequence a -> Bool

schedule :: (Generator a b, Validator b) => [a] -> Alternatives (Sequence b) 
schedule (g:[]) = do
  x <- generate g
  return $ Sequence [x]
schedule (g:gs) =         
  let possibleSchedules = schedule gs
  in do
    Sequence s <- possibleSchedules
    x <- generate g 
    guard $ all (not . (conflict x)) s
    let s' = Sequence (x:s)
    guard $ isValid s'
    return s'
schedule [] = Alternatives []
