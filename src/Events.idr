module Events

import Control.ST

import Objects
import Input





-- interface Event where


-- %access public export
--

public export
data Event = MovementStart MoveDirection ObjectId
           | MovementStop ObjectId
           | Attack ObjectId
           | Jump ObjectId
           | Collision ObjectId ObjectId

%name Events.Event event

export
Show Event where
  show (MovementStart direction x) = "MovementStart " ++ show direction ++ " " ++ x
  show (MovementStop x) = "MovementStop " ++ x
  show (Attack x) = "Attack " ++ x
  show (Jump x) = "Jump " ++ x

export
inputToEvent : (id : String) -> (event : InputEvent) -> Maybe Event
inputToEvent id (CommandStart (Movement Left)) = Just $ MovementStart Leftward id
inputToEvent id (CommandStart (Movement Right)) = Just $ MovementStart Rightward id
inputToEvent id (CommandStart (Movement Up)) = Just $ Jump id
inputToEvent id (CommandStart (Movement Down)) = Nothing
inputToEvent id (CommandStart Attack) = Just $ Attack id

inputToEvent id (CommandStop (Movement Left)) = Just $ MovementStop id
inputToEvent id (CommandStop (Movement Right)) = Just $ MovementStop id
inputToEvent id (CommandStop (Movement Up)) = Nothing
inputToEvent id (CommandStop (Movement Down)) = Nothing
inputToEvent id (CommandStop Attack) = Nothing

export
reportEvents : ConsoleIO m => (List Events.Event) -> STrans m () xs (const xs)
reportEvents [] = pure ()
reportEvents xs = printLn xs
