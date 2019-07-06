module Camera

import Graphics.SDL2 as SDL2

import Physics.Vector2D
import Settings
import Common

public export
record Camera where
  constructor MkCamera
  position : Vector2D
  zoom : Double
  rotation : Double
  resolution : (Int, Int)
  yd : Double
%name Camera camera

export
defaultCamera : Camera
defaultCamera = MkCamera
  (0, 0) (zoom defaultDisplaySettings) 0 (resolution defaultDisplaySettings)
  (cameraYD defaultDisplaySettings)

export
resolution' : Camera -> (Double, Double)
resolution' = cast . resolution

export
translate : Vector2D -> Camera -> Camera
translate a = record { position = a }

export
fromSettings : DisplaySettings -> Camera
fromSettings settings = record { resolution = resolution settings,
                                 yd = cameraYD settings,
                                 zoom = zoom settings } defaultCamera

export
positionToScreen : Camera -> Vector2D -> (Int, Int)
positionToScreen camera@(MkCamera (cx, cy) zoom _ resolution yd) (ox, oy)
  = let (rx, ry) = resolution' camera
        (x, y) = zoom `scale` (ox - cx, cy - oy) in
        (round $ x + rx/2, round $ y + ry/2)

export
dimToScreen : Camera -> Vector2D -> (Int, Int)
dimToScreen (MkCamera _ zoom _ _ _) (x, y) = (round $ zoom * x, round $ zoom * y)

export
screenToPosition : Camera -> (Int, Int) -> Vector2D
screenToPosition camera (sx, sy)
  = let (rx, ry) = resolution' camera
        screenVector = (cast sx - rx/2, -(cast sy - ry/2))
        s = (1.0 / zoom camera) `scale` screenVector
        in position camera + s

export
getRect : Camera -> (position : Vector2D) -> (dimensions : Vector2D) -> SDLRect
getRect camera position dimensions
  = let dimensions' = (fst dimensions, - (snd dimensions))
        (x, y) = positionToScreen camera (position - dimensions')
        (x', y') = positionToScreen camera (position + dimensions')
        (w, h) = (x' - x, y' - y) in MkSDLRect x y w h
