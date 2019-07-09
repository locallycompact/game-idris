module AI.AIScript

import Events
import Descriptors
import AI.Controller
import Common
import Objects
import Physics.Vector2D

public export
data AIScript : Type -> Type where
  AICommand : (id : ObjectId) -> Command -> AIScript ()
  Transition : (id : ObjectId) -> AIState -> Maybe AIAction -> AIScript ()
  UpdateData : (id : ObjectId) -> (f : AIData -> AIData) -> AIScript ()
  GetStartTime : (id : ObjectId) -> AIScript (Maybe Int) -- time since in this state
  GetDirection : (id : ObjectId) -> AIScript (Maybe AIDirection)
  GetController : (id : ObjectId) -> AIScript (Maybe AIController)

  SetTarget : (id : ObjectId) -> (target_id : ObjectId) -> AIScript ()
  GetPosition : (id : ObjectId) -> AIScript (Maybe Vector2D)

  GetTime : AIScript Int -- global time

  Log : String -> AIScript ()

  Pure : (res : a) -> AIScript a
  (>>=) : AIScript a -> (a -> AIScript b) -> AIScript b

export
Functor AIScript where
  map f x = do res <- x
               Pure (f res)

export
Applicative AIScript where
  pure = Pure
  sf <*> sa = do f <- sf
                 a <- sa
                 pure (f a)

export
Monad AIScript where
  (>>=) = AIScript.(>>=)

public export
UnitAIScript : Type
UnitAIScript = AIScript ()

runGenericHandler : (id : ObjectId) ->
                    (controller : AIController) ->
                    (getHandler : AIController -> Maybe Transition) ->
                    UnitAIScript
runGenericHandler id controller getHandler = case getHandler controller of
  Nothing => pure ()
  Just (MkTransition state action) => Transition id state action

collisionScript : CollisionData -> AIController -> UnitAIScript
collisionScript (MkCollisionData self other) controller
  = runGenericHandler (id self) controller collisionHandler

export
eventScript : (event : Events.Event) -> UnitAIScript
eventScript (CollisionStart one two) = with AIScript do
  Just controller_one <- GetController (id one) | pure ()
  Just controller_two <- GetController (id two) | pure ()
  let cdata = buildCollisionData one two
  collisionScript (cdata First) controller_one
  collisionScript (cdata Second) controller_two
eventScript (CollisionStop x y) = pure ()
eventScript (Hit attacker target damage) = with AIScript do
  Just controller <- GetController target | pure ()
  SetTarget target attacker -- implicit action: target last hit
  runGenericHandler target controller hitHandler

export
timeScript : (time : Int) -> (id : ObjectId) -> AIController -> UnitAIScript
timeScript time id controller = case currentHandlers controller of
  Nothing => pure ()
  Just handlers => case onTime handlers of
    Nothing => pure ()
    Just (duration, MkTransition state action) => with AIScript do
      Just transitioned <- GetStartTime id | pure ()
      let passed = (cast time) / 1000.0 - (cast transitioned) / 1000.0
      when (passed > duration) $
        Transition id state action

export
chaseScript : (id : ObjectId) -> AIController -> UnitAIScript
chaseScript id controller = case state controller of
  Chase => case target controller of
    Nothing => pure ()
    Just target_id => with AIScript do
      Just target_position <- GetPosition target_id | pure ()
      Just my_position <- GetPosition id | pure ()
      if (fst my_position > fst target_position)
        then AICommand id $ Start $ Movement Left
        else AICommand id $ Start $ Movement Right
  _ => pure ()

export
mainScript : (time : Int) -> (id : ObjectId) -> AIController -> UnitAIScript
mainScript time id controller = with AIScript do
  timeScript time id controller
  chaseScript id controller

export
actionToScript : (id : ObjectId) -> AIAction -> UnitAIScript
actionToScript id MoveRight = AICommand id (Start (Movement Right))
actionToScript id MoveLeft = AICommand id (Start (Movement Left))
actionToScript id ChangeDirection = with AIScript do
  Just direction <- GetDirection id | pure ()
  case direction of
    Leftward => AICommand id (Start (Movement Right))
    Rightward => AICommand id (Start (Movement Left))
actionToScript id Attack = pure ()
actionToScript id Stop = with AIScript do
  AICommand id (Stop (Movement Right))
  AICommand id (Stop (Movement Left))
  AICommand id (Stop (Movement Up))
  AICommand id (Stop (Movement Down))
