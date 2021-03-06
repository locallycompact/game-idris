module Creator

import Graphics.SDL2

import Client.UI
import Client.Rendering
import Client.Rendering.Camera
import Client.Input
import Client.SDL
import Client.ClientCommands
import Creator.PCreator
import Creator.MapCreator
import Creator.UI.ObjectsSurfaces
import Creator.MapCreator.PMapCreator
import Creator.MapCreator.Tools
import Descriptions.MapDescription
import Descriptions.SurfaceDescription
import GameIO
import Objects
import JSONCache
import Settings
import Commands

public export
interface Creator (m : Type -> Type) where
  SCreator : Type

  startCreator : (settings : ClientSettings) ->
                 (preload : PreloadResults) ->
                 ST m Var [add SCreator]
  endCreator : (creator : Var) -> ST m () [remove creator SCreator]

  queryPCreator : (creator : Var) ->
                  (q : PCreator -> a) ->
                  ST m a [creator ::: SCreator]
  updatePCreator : (creator : Var) ->
                   (f : PCreator -> PCreator) ->
                   ST m () [creator ::: SCreator]

  queryPMapCreator : (creator : Var) ->
                     (q : PMapCreator -> a) ->
                     ST m a [creator ::: SCreator]
  updatePMapCreator : (creator : Var) ->
                      (f : PMapCreator -> PMapCreator) ->
                      ST m () [creator ::: SCreator]

  loadMap : (creator : Var) ->
            (map_ref : ContentReference) ->
            ST m () [creator ::: SCreator]

  getMap : (creator : Var) -> ST m (Maybe MapDescription) [creator ::: SCreator]

  iterate : (creator : Var) ->
            ST m Bool [creator ::: SCreator]

  toggleRoot : (creator : Var) ->
               (ref : ContentReference) ->
               (x : Int) ->
               (y : Int) ->
               ST m () [creator ::: SCreator]


  private
  updateObjectList : (creator : Var) -> ST m () [creator ::: SCreator]

  private
  setTool : (creator : Var) ->
            (tool : Tool) ->
            ST m () [creator ::: SCreator]
  private
  unsetTool : (creator : Var) ->
            ST m () [creator ::: SCreator]

  private
  processClick : (creator : Var) ->
                 (click : Click) ->
                 ST m () [creator ::: SCreator]

  private
  processClicks : (creator : Var) ->
                  (clicks : List Click) ->
                  ST m () [creator ::: SCreator]

  private
  render : (creator : Var) ->
           ST m () [creator ::: SCreator]

  private
  runClientCommand : (creator : Var) ->
                     (clientCommand : ClientCommand) ->
                     ST m () [creator ::: SCreator]
  private
  runClientCommands : (creator : Var) ->
                      (clientCommands : List ClientCommand) ->
                      ST m () [creator ::: SCreator]

  private
  runCommand : (creator : Var) ->
               (command : Command) ->
               ST m () [creator ::: SCreator]
  private
  runCommands : (creator : Var) ->
                (commands : List Command) ->
                ST m () [creator ::: SCreator]

  private
  feedUI : (creator : Var) ->
           (clientCommands : List ClientCommand) ->
           ST m (List ClientCommand) [creator ::: SCreator]

  private
  getClicks : (creator : Var) -> ST m (List Click) [creator ::: SCreator]

export
(GameIO m, Rendering m, SDL m) => Creator m where
  SCreator = Composite [
    State PCreator,
    SSDL {m},
    SMapCreator {m},
    SUI {m}
  ]

  startCreator settings preload = with ST do
    pcreator <- new $ MkPCreator preload
    sdl <- startSDL (resolutionX settings) (resolutionY settings) preload
    map_creator <- startMapCreator preload
    ui <- startUI preload
    creator <- new ()
    combine creator [pcreator, sdl, map_creator, ui]
    pure creator

  endCreator creator = with ST do
    [pcreator, sdl, map_creator, ui] <- split creator
    endSDL sdl
    endMapCreator map_creator
    endUI ui
    delete pcreator
    delete creator

  queryPCreator creator q = with ST do
    [pcreator, sdl, map_creator, ui] <- split creator
    pcreator' <- read pcreator
    combine creator [pcreator, sdl, map_creator, ui]
    pure $ q pcreator'

  updatePCreator creator f = with ST do
    [pcreator, sdl, map_creator, ui] <- split creator
    update pcreator f
    combine creator [pcreator, sdl, map_creator, ui]

  queryPMapCreator creator q = with ST do
    [pcreator, sdl, map_creator, ui] <- split creator
    result <- MapCreator.queryPMapCreator map_creator q
    combine creator [pcreator, sdl, map_creator, ui]
    pure result

  updatePMapCreator creator f = with ST do
    [pcreator, sdl, map_creator, ui] <- split creator
    MapCreator.updatePMapCreator map_creator f
    combine creator [pcreator, sdl, map_creator, ui]

  loadMap creator map_ref = with ST do
    [pcreator, sdl, map_creator, ui] <- split creator
    MapCreator.loadMap map_creator map_ref
    combine creator [pcreator, sdl, map_creator, ui]

  getMap creator = with ST do
    [pcreator, sdl, map_creator, ui] <- split creator
    res <- MapCreator.getMap map_creator
    combine creator [pcreator, sdl, map_creator, ui]
    pure res

  render creator = with ST do
    [pcreator, sdl, map_creator, ui] <- split creator
    clear sdl
    renderMapCreator map_creator sdl
    renderUI ui sdl
    present sdl
    combine creator [pcreator, sdl, map_creator, ui]

  runClientCommand creator cmd = with ST do
    [pcreator, sdl, map_creator, ui] <- split creator
    MapCreator.runClientCommand map_creator cmd
    combine creator [pcreator, sdl, map_creator, ui]

  runClientCommands creator [] = pure ()
  runClientCommands creator (cmd::xs) = with ST do
    runClientCommand creator cmd
    runClientCommands creator xs

  runCommand creator command = with ST do
    [pcreator, sdl, map_creator, ui] <- split creator
    MapCreator.runCommand map_creator command
    combine creator [pcreator, sdl, map_creator, ui]

  runCommands creator [] = pure ()
  runCommands creator (cmd::xs)
    = runCommand creator cmd >>= const (runCommands creator xs)

  setTool creator tool = with ST do
    [pcreator, sdl, map_creator, ui] <- split creator
    MapCreator.setTool map_creator tool
    combine creator [pcreator, sdl, map_creator, ui]

  unsetTool creator = with ST do
    [pcreator, sdl, map_creator, ui] <- split creator
    MapCreator.unsetTool map_creator
    combine creator [pcreator, sdl, map_creator, ui]

  processClick creator (Inventory x) = pure ()
  processClick creator (Character x) = pure ()
  processClick creator MainMenuExit = pure ()
  processClick creator MainMenuOptions = pure ()
  processClick creator CreatorRemove = setTool creator Tools.Remove
  processClick creator CreatorAdd = with ST do
    unsetTool creator
    toggleRoot creator "main/ui/creator/objects.json" 300 300
    updateObjectList creator
  processClick creator CreatorAddWall = with ST do
    unsetTool creator
    toggleRoot creator "main/ui/creator/walls.json" 600 300
  processClick creator (CreatorObjectSelect ref) = with ST do
    setTool creator $ Tools.Add ref
    toggleRoot creator "main/ui/creator/objects.json" 300 300
  processClick creator CreatorWallSelectRect = with ST do
    setTool creator Tools.AddRectWall
    toggleRoot creator "main/ui/creator/walls.json" 600 300
  processClick creator CreatorWallSelectChain = with ST do
    setTool creator Tools.AddChainWall
    toggleRoot creator "main/ui/creator/walls.json" 600 300
  processClick creator CreatorSetSpawn = setTool creator Tools.SetSpawn
  processClick creator CreatorMove = setTool creator Tools.Move
  processClick creator click = lift $ log $
    "unhandled click in creator: " ++ show click

  processClicks creator [] = pure ()
  processClicks creator (x::xs) = processClick creator x >>=
    const (processClicks creator xs)

  updateObjectList creator = with ST do
    preload' <- queryPCreator creator preload
    let objectsSurfaces' = objectsSurfaces preload'
    [pcreator, sdl, map_creator, ui] <- split creator
    setSurfaceChildren ui objectslistRef objectsSurfaces'
    combine creator [pcreator, sdl, map_creator, ui]

  iterate creator = with ST do
    render creator
    sdl_events <- poll
    camera <- queryPMapCreator creator camera
    case processEvents "map creator" camera sdl_events of
      Right (clientCommands, commands) => with ST do
        clientCommands' <- feedUI creator clientCommands
        clicks <- getClicks creator
        runClientCommands creator clientCommands
        runCommands creator commands
        processClicks creator clicks
        [pcreator, sdl, map_creator, ui] <- split creator
        MapCreator.iterate map_creator
        combine creator [pcreator, sdl, map_creator, ui]
        pure True
        -- ?hmmm
        -- clientCommands' <- feedUI client clientCommands
        -- fromClient <- runClientCommands client clientCommands' []
        -- clicks <- getClicks client
        -- clickCommands <- processClicks client clicks []
        -- movement <- queryPClient client lastFacing {s=Connected}
        -- let filtered = filterMovement movement commands
        -- let newCommands = clickCommands ++ fromClient ++ filtered
        -- runCommands client newCommands
        -- setNewFacing client filtered
        -- pure $ Right newCommands
        -- pure True
      _ => pure False

  feedUI creator clientCommands = with ST do
    [pcreator, sdl, map_creator, ui] <- split creator
    clientCommands' <- eatClientCommands ui clientCommands
    combine creator [pcreator, sdl, map_creator, ui]
    pure clientCommands'

  getClicks creator = with ST do
    [pcreator, sdl, map_creator, ui] <- split creator
    clicks <- UI.getClicks ui
    combine creator [pcreator, sdl, map_creator, ui]
    pure clicks

  toggleRoot creator ref x y = with ST do
    [pcreator, sdl, map_creator, ui] <- split creator
    UI.toggleRoot ui ref x y
    combine creator [pcreator, sdl, map_creator, ui]
