module Descriptions.ObjectDescription.RenderDescription

import Physics.Vector2D

import Descriptions.Color
import GameIO
import Exception

public export
record EquipmentRender where
  constructor MkEquipmentRender
  head : Vector2D
  hands : Vector2D
  legs : Vector2D

ObjectCaster EquipmentRender where
  objectCast dict = with Checked do
    head <- getVector "head" dict
    hands <- getVector "hands" dict
    legs <- getVector "legs" dict
    pure $ MkEquipmentRender head hands legs

Serialize EquipmentRender where
  toDict er = with ST do
    erObject <- makeObject
    addVector erObject "head" $ head er
    addVector erObject "hands" $ hands er
    addVector erObject "legs" $ legs er
    getDict erObject

public export
record AnimationParameters where
  constructor MkAnimationParameters
  ref : ContentReference
  dimensions : Vector2D
  fps : Double
  equipment : Maybe EquipmentRender
%name AnimationParameters animation_parameters

export
getHandsOffset : AnimationParameters -> Vector2D
getHandsOffset = fromMaybe nullVector . map hands . equipment

export
Show AnimationParameters where
  show (MkAnimationParameters ref dimensions fps equip)
    =  "{ ref: " ++ show ref
    ++ ", dimensions: " ++ show dimensions
    ++ ", fps: " ++ show fps
    ++ " }"

export
ObjectCaster AnimationParameters where
  objectCast dict = with Checked do
    animation <- getString "animation" dict
    dimensions <- getVector "dimensions" dict
    fps <- getDouble "fps" dict
    equip <- the (Checked (Maybe EquipmentRender)) $ getCastableMaybe "equip" dict
    pure $ MkAnimationParameters animation dimensions fps equip

export
Serialize AnimationParameters where
  toDict ap = with ST do
    apObject <- makeObject
    addString apObject "animation" $ ref ap
    addVector apObject "dimensions" $ dimensions ap
    addDouble apObject "fps" $ fps ap
    addObjectMaybe apObject "equip" $ equipment ap
    getDict apObject

public export
AnimationParametersDict : Type
AnimationParametersDict = Dict String AnimationParameters

public export
data RenderMethod = Tiled ContentReference Vector2D (Nat, Nat)
                  | ColoredCircle Color Double
                  | ColoredRect Color Vector2D
                  | OutlineRect Color Vector2D
                  | Single ContentReference Vector2D Bool
                  | Animated AnimationParametersDict
%name RenderMethod render_description

export
getSingleAnimation : AnimationParametersDict -> Maybe (ContentReference, Vector2D)
getSingleAnimation = map refDimensions . head' . Dict.toList where
  refDimensions : (String, AnimationParameters) -> (ContentReference, Vector2D)
  refDimensions (stateName, params) = (ref params, dimensions params)

export
getSingleAnimation' : AnimationParametersDict -> Maybe AnimationParameters
getSingleAnimation' = map snd . head' . Dict.toList

export
Show RenderMethod where
  show (Tiled ref tileDims repeat)
    =    "tiled with " ++ show ref
    ++ " (tileDims: " ++ show tileDims
    ++ ", repeated: " ++ show repeat
    ++  ")"
  show (ColoredCircle color radius) = "filled circle with " ++ show color
  show (ColoredRect color dims) = "filled rect with " ++ show color
  show (OutlineRect color dims) = "outline rect with " ++ show color
  show (Single ref dims facingRight) = "single with " ++ ref ++ ", dims: " ++ show dims
  show (Animated x) = "animated ( " ++ show x ++ " )"

toParameters : (String, JSON) -> Checked (String, AnimationParameters)
toParameters (state, json) = case the (Checked AnimationParameters) (cast json) of
  Left e => fail e
  Right aparams => pure (state, aparams)

getAnimationStates : Dict String JSON -> Checked (Dict String AnimationParameters)
getAnimationStates dict = case lookup "states" dict of
  Nothing => fail "missing animation states"
  Just (JObject xs) => catResults (map toParameters xs) >>= pure . fromList
  _ => fail "animation states aren't JObject"

export
ObjectCaster RenderMethod where
  objectCast dict = with Checked do
    type <- getString "type" dict
    case type of
      "color" => with Checked do
        color <- getColor "color" dict
        case (hasKey "dimensions" dict, hasKey "radius" dict) of
          (True, True) => fail "dimensions and radius can't both be present for render method color"
          (True, False) => getVector "dimensions" dict >>= pure . ColoredRect color
          (False, True) => getDouble "radius" dict >>= pure . ColoredCircle color
          (False, False) => fail "either dimensions or radius must be present for render method color"
      "outline_rect" => with Checked do
        color <- getColor "color" dict
        dimensions <- getVector "dimensions" dict
        pure $ OutlineRect color dimensions
      "single" => with Checked do
        image <- getString "image" dict
        dimensions <- getVector "dimensions" dict
        facingRight <- getBoolOrDefault True "facingRight" dict
        pure $ Single image dimensions facingRight
      "tile" => with Checked do
        image <- getString "image" dict
        tileDims <- getVector "tileDims" dict
        (nx, ny) <- getIntPair "repeat" dict
        pure $ Tiled image tileDims (cast nx, cast ny)
      "animated" => getAnimationStates dict >>= pure . Animated
      _ => fail "render type must be of \"single\"|\"tile\"|\"animated\"|\"color\""

export
Serialize RenderMethod where
  toDict (Tiled ref tileDims (nx, ny)) = with ST do
    rmObject <- makeObject
    addString rmObject "type" "tile"
    addString rmObject "image" ref
    addVector rmObject "tileDims" tileDims
    addIntPair rmObject "repeat" (cast nx, cast ny)
    getDict rmObject
  toDict (ColoredCircle color radius) = with ST do
    rmObject <- makeObject
    addString rmObject "type" "color"
    addColor rmObject "color" color
    addDouble rmObject "radius" radius
    getDict rmObject
  toDict (ColoredRect color dims) = with ST do
    rmObject <- makeObject
    addString rmObject "type" "color"
    addColor rmObject "color" color
    addVector rmObject "dimensions" dims
    getDict rmObject
  toDict (OutlineRect color dims) = with ST do
    rmObject <- makeObject
    addString rmObject "type" "outline_rect"
    addColor rmObject "color" color
    addVector rmObject "dimensions" dims
    getDict rmObject
  toDict (Single ref dims facingRight) = with ST do
    rmObject <- makeObject
    addString rmObject "type" "single"
    addString rmObject "image" ref
    addVector rmObject "dimensions" dims
    addBool rmObject "facingRight" facingRight
    getDict rmObject
  toDict (Animated statesDict) = with ST do
    rmObject <- makeObject
    addString rmObject "type" "animated"
    addObject rmObject "states" $ map serializeToJSON statesDict
    getDict rmObject

public export
record InfoRenderParameters where
  constructor MkInfoRenderParameters
  yd : Double

export
Show InfoRenderParameters where
  show info = "{ yd: " ++ show (yd info) ++ " }"

ObjectCaster InfoRenderParameters where
  objectCast dict = with Checked do
    yd <- getDouble "yd" dict
    pure $ MkInfoRenderParameters yd

Serialize InfoRenderParameters where
  toDict irp = with ST do
    irpObject <- makeObject
    addDouble irpObject "yd" $ yd irp
    getDict irpObject

public export
record RenderDescription where
  constructor MkRenderDescription
  method : Maybe RenderMethod
  method_creator : Maybe RenderMethod
  info : Maybe InfoRenderParameters
  layer : Maybe Nat

export
Show RenderDescription where
  show rd
    =  "{ method: " ++ show (method rd)
    ++ ", info: " ++ show (info rd)
    ++ ", layer: " ++ show (layer rd)
    ++ " }"

export
ObjectCaster RenderDescription where
  objectCast dict = with Checked do
    method <- the (Checked (Maybe RenderMethod)) $
      getCastableMaybe "method" dict
    method_creator <- the (Checked (Maybe RenderMethod)) $
      getCastableMaybe "method_creator" dict
    info <- the (Checked (Maybe InfoRenderParameters)) $
      getCastableMaybe "info" dict
    let layer = eitherToMaybe $ getInt "layer" dict
    pure $ MkRenderDescription method method_creator info (map cast layer)

export
Serialize RenderDescription where
  toDict rd = with ST do
    rdObject <- makeObject
    addObjectMaybe rdObject "method" $ method rd
    addObjectMaybe rdObject "method_creator" $ method_creator rd
    addObjectMaybe rdObject "info" $ info rd
    addIntMaybe rdObject "layer" $ map cast $ layer rd
    getDict rdObject

export
pickRenderMethod : RenderDescription -> Maybe RenderMethod
pickRenderMethod desc = case (method desc, method_creator desc) of
  (Just method, _) => Just method
  (Nothing, Just method) => Just method
  _ => Nothing
