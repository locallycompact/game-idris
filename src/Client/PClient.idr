module Client.PClient

import Client.UI.Inventory
import JSONCache
import GameIO
import Exception
import Descriptions.MapDescription
import Descriptions.ItemDescription
import Descriptions.SurfaceDescription
import Descriptions.ObjectDescription
import Descriptions.ObjectDescription.RenderDescription
import Dynamics.MoveDirection
import Objects
import Commands
import Settings
import Timeline

public export
record PClient where
  constructor MkPClient
  preload : PreloadResults
  settings : ClientSettings
  lastFacing : Maybe Direction

public export
record SessionData where
  constructor MkSessionData
  characterId : ObjectId -- as an object in the scene
  character : Character -- needed to feed UI

export
updateSettings : (f : ClientSettings -> ClientSettings) -> PClient -> PClient
updateSettings f = record { settings $= f }

export
setCharacter : Character -> SessionData -> SessionData
setCharacter character' = record { character = character' }

export
withRender : Maybe RenderDescription -> ObjectDescription -> ObjectDescription
withRender Nothing = id
withRender render'@(Just x) = record { render = render' }

export
setLastFacing : Maybe Direction -> PClient -> PClient
setLastFacing direction = record { lastFacing = direction }
