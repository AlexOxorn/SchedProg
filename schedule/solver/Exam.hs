{-# LANGUAGE GADTs #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}

module Exam where

import Control.Applicative ((<$>))
import Control.Arrow ((&&&))
import Control.Lens
import Control.Monad
import Data.Default
import Data.Function (on)
import Data.List (sortBy, groupBy, intersperse)
import Data.Set (Set, toList, intersection)
import Data.Maybe
import Schedule     
  
  
-- Week days

data WeekDay = None | Monday | Tuesday | Wednesday | Thursday | Friday
     deriving (Enum, Eq, Ord)
              
instance Default WeekDay where 
  def = None
              
instance Show WeekDay where
  show Monday    = "M"
  show Tuesday   = "T"
  show Wednesday = "W"
  show Thursday  = "R"
  show Friday    = "F"
  show _         = ""

weekdays = [Monday, Tuesday, Wednesday, Thursday, Friday]


-- Time

data Time = Time { _day :: WeekDay, _start :: Double, _end :: Double }
            deriving(Eq)
                    
instance Show Time where
  show (Time day start end) = (show day) ++ " " ++ (show start) ++ "-" ++ (show end)
                    
conflictTime :: Time -> Time -> Bool
conflictTime (Time day1 start1 end1) (Time day2 start2 end2) = day1 == day2 &&
             (
               (start1 >= start2 && start1 < end2)
                 ||
               (end1 > start2 && end1 <= end2)
             )


makeLenses ''Time

instance Default Time where
  def = Time def def def

-- Course information

data CourseTitle = CourseTitle { _name :: String, _code :: String, _stream :: Char }
                   deriving(Eq)
                           
instance Show CourseTitle where
  show (CourseTitle name code stream) = code ++ "/" ++ [stream] ++ " - " ++ name
makeLenses ''CourseTitle

instance Default Char where
  def = '\0'

instance Default CourseTitle where
  def = CourseTitle def def def
                           
-- Course Classes
  
data Class = Class { _title :: CourseTitle, _time :: Time, _room :: Set String, _teacher :: Set String}
             deriving(Eq)
                     
instance Show Class where
  show (Class title time room teacher) = "Class {\"" ++ (show title) ++ "\" at " ++ (show time) ++ " with " ++ (show teacher) ++ " in " ++ (show room) ++ "}" 

makeLenses ''Class

instance Default Class where
  def = Class def def def def


conflictClass :: Class -> Class -> Bool
conflictClass (Class title1 time1 rooms1 teachers1) (Class title2 time2 rooms2 teachers2) = 
  (title1 == title2 || notDisjoint rooms1 rooms2 || notDisjoint teachers1 teachers2)
  && conflictTime time1 time2
    where notDisjoint s1 s2 = (length . toList) (intersection s1 s2) == 0
  
containsConflict :: [Class] -> Bool
containsConflict classes = any id [ conflictClass c1 c2 | c1 <- classes, c2 <- classes, c1 /= c2 ]



-- instance Generator g => Generator C

-- makeCourse :: (Generator g) => CourseTitle -> [String] -> [String] -> g -> [Class]
-- makeCourse title teachers rooms gen =
--              [ map (\t -> let (Time day start end) = t in Block stream teacher room day start end) times | times <- generate gen ]
             
        
-- do need GADT for this?
infixr 4 :++:
data CombinedGenerator where
  (:++:) :: (Generator a [Time], Generator b [Time]) => a -> b -> CombinedGenerator

instance Generator CombinedGenerator [Time] where
  generate (g1 :++: g2) = Alternatives [ t1 ++ t2 | t1 <- getAlternatives (generate g1), t2 <- getAlternatives (generate g2), not $ conflictT t1 t2 ]
    where conflictT [] t2s = False
          conflictT (t1:t1s) t2s = (any (conflictTime t1) t2s) || (conflictT t1s t2s) 


dayStart = 8.5
dayEnd = 17.5
startTimes duration = takeWhile (<= dayEnd - duration) $ iterate (+1.5) dayStart

data StandardPair = StandardPair { standardPairDuration :: Double }

instance Generator StandardPair [Time] where
  generate (StandardPair duration) = 
    Alternatives [ [Time day1 start (start + duration), Time day2 start (start + duration)] |
                   (day1, day2) <- dayPairs,
                   start <- startTimes duration
                                                                                            ]
    where dayPairs = [(Monday, Wednesday), (Tuesday, Thursday), (Wednesday, Friday)]

singleStdPair = StandardPair 1.5
doubleStdPair = StandardPair 3

-- data CustomPair = CustomPair { customPairDay1 :: WeekDay, customPairDay2 :: WeekDay, custormPairDuration :: Double }

-- instance Generator CustomPair where
--   generate (CustomPair day1 day2 duration) =
--                 [ [ Time day1 start (start + duration), Time day2 start (start + duration)] |
--                              start <- startTimes duration
--                            ]


data StandardSingle = StandardSingle { standardSingleDuration :: Double }

instance Generator StandardSingle [Time] where
  generate (StandardSingle duration) =
    Alternatives [ [Time day start (start + duration)] |
                   day <- weekdays,
                   start <- startTimes duration
                                                     ]


data ClassGenerator where
  ClassGenerator :: (Generator a [Time]) => Class -> a -> ClassGenerator
  
instance Generator ClassGenerator [Class] where
  generate (ClassGenerator c g) = Alternatives [ [ c & time .~ t' | t' <- t ] | t <- getAlternatives $ generate g ] 
  

-- validators
  
myGroupBy :: (Ord b) => (a -> b) -> [a] -> [(b, [a])]
myGroupBy f = map (f . head &&& id)
              . groupBy ((==) `on` f)
              . sortBy (compare `on` f)


validateTeacherLunch [Class] -> Bool
validateTeacherLunch classes = undefined
where
  -- trim list to only classes that can possibly conflict
  relevantClasses classes = filter (\c -> c^.time.start < 13 && c^.time.end > 11) classes

-- ideas: time "set" operations, merge times, time intersection/union/differece, time add and minus
  
timeMinus :: Time -> Time -> Time
timeMinus t@(Time day1 start1 end1) (Time day2 start2 end2) = 
  if day1 == day2
  then undefined
  else t


instance Validator [Class] where
  conflict [] _ = False
  conflict (c:cs) cs' = (any id $ map (conflictClass c) cs') || (conflict cs cs')
  isValid _ = True
  
