module Dynamics.DynamicsCommand

import Physics.Box2D
import Physics.Vector2D

import Dynamics.DynamicsControl
import Dynamics.MoveDirection
import Descriptions.ObjectDescription.BodyFlags
import Objects
import Commands
import Exception
import Descriptions.MapDescription
import Descriptions.JointDescription
import Descriptions.ObjectDescription
import Descriptions.ObjectDescription.BodyDescription

-- indirect way of calling methods because I don't know how to pass the dynamics
-- Var to the Client and Server directly
public export
data DynamicsCommand
  = Create ObjectId
           BodyDefinition
           (List FixtureDefinition)
           (Maybe ControlParameters)
           (List PhysicsEffect)
           (Maybe Vector2D) -- impulse
           (Maybe BodyFlags)
  | CreateJoint ObjectId JointDescription
  | Destroy ObjectId
  | UpdateControl ObjectId (ControlState -> ControlState)
  | ApplyImpulse ObjectId Vector2D
  | SetFacing ObjectId MoveDirection
  | QueryFor ObjectId String Double
  | SetMaskBits ObjectId (List String)
  | UnsetMaskBits ObjectId (List String)

export
fromCommand : Command -> Maybe DynamicsCommand
fromCommand (Start (Movement direction) id)
  = Just $ UpdateControl id (startMoveAction direction)
fromCommand (Stop (Movement direction) id)
  = Just $ UpdateControl id (stopMoveAction direction)
fromCommand (Stop (Face direction) id)
  = Just $ UpdateControl id (faceAction direction)
fromCommand (Start (Attack x) id) = Just $ UpdateControl id startAttacking
fromCommand (Stop (Attack x) id) = Just $ UpdateControl id stopAttacking
fromCommand (Start Walk id) = Just $ UpdateControl id startWalking
fromCommand (Stop Walk id) = Just $ UpdateControl id stopWalking
fromCommand (Start (Interact x) id) = Nothing
fromCommand (Stop (Interact x) id) = Just $ QueryFor id "interact" x
fromCommand _ = Nothing

export
filterControl : ObjectId -> List DynamicsCommand -> List DynamicsCommand
filterControl id = filter notSame where
  notSame : DynamicsCommand -> Bool
  notSame (UpdateControl id' f) = id /= id'
  notSame _ = True

export
Show DynamicsCommand where
  show (Create id bodyDef fixtures control effects impulse flags) = "create " ++ id
  show (Destroy id) = "destroy " ++ id
  show (UpdateControl id f) = "update control of " ++ id
  show (QueryFor id name x) = id ++ " querying " ++ show x ++ " (" ++ name ++ ")"
  show (CreateJoint id desc) = "create joint " ++ id
  show (SetMaskBits id bits) = "set mask bits " ++ show bits ++ " to " ++ id
  show (UnsetMaskBits id bits) = "unset mask bits " ++ show bits ++ " to " ++ id

applyCatMaskIndex' : BodyDescription -> FixtureDefinition -> FixtureDefinition
applyCatMaskIndex' body_desc fixture_def = record {
    categoryBits = fixturePrecedence (categoryBits body_desc) (categoryBits fixture_def),
    maskBits = fixturePrecedence (maskBits body_desc) (maskBits fixture_def),
    groupIndex = fixturePrecedence (groupIndex body_desc) (groupIndex fixture_def)
  } fixture_def where
      fixturePrecedence : Maybe Int -> Maybe Int -> Maybe Int
      fixturePrecedence a b = case (a, b) of
        (Just a, Just b) => Just b
        (Just a, Nothing) => Just a
        (Nothing, Just b) => Just b
        (Nothing, Nothing) => Nothing

applyCatMaskIndex : BodyDescription -> List FixtureDefinition -> List FixtureDefinition
applyCatMaskIndex desc = map $ applyCatMaskIndex' desc

bodyDescFail : String
bodyDescFail = "either creation or object description must have body description, but not both"

getBodyDescription : Creation -> ObjectDescription -> Checked BodyDescription
getBodyDescription creation object_description
  = case (body object_description, body creation) of
      (Just body_desc, Nothing) => pure body_desc
      (Nothing, Just body_desc) => pure body_desc
      _ => fail bodyDescFail

export
createObjectCommand : Creation -> ObjectDescription -> ObjectId -> Checked DynamicsCommand
createObjectCommand creation object_description id = with Checked do
  body_description <- getBodyDescription creation object_description
  let bodyDef = creationBodyDescriptionToDefinition creation body_description
  let fixtures = applyCatMaskIndex body_description (fixtures body_description)
  let effects = effects body_description
  let control = map parametersFromDescription $ control object_description
  let impulse  = impulse creation
  pure $ Create id bodyDef fixtures control effects impulse (flags body_description)
