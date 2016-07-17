port module Game exposing (..)

import Html exposing (..)
import Html.App as App
import Html.Attributes exposing (..)
import Html.Events exposing (onInput, onClick)
import Json.Decode exposing (..)
import Task exposing (Task)
import WebSocket
import Effects exposing (Effects)
import Keyboard.Extra as Keyboard

-- Local imports

import Join
import Map
import GameState exposing (GameState)
import Message exposing (..)

-- Action

type Msg =
    UpdateGameState GameState |
    KeyboardMsg Keyboard.Msg |
    JoinMsg Join.Msg |
    MapMsg Map.Msg |
    PerformCmd (Cmd Msg) |
    WsReceiveMessage String |
    WsSendMessage String

-- Model

type alias Flags = {
    address : String
}

type alias Model = {
    state : GameState,
    address: String,
    keyboardModel : Keyboard.Model,
    joinModel : Join.Model,
    mapModel : Map.Model
}

init : Flags -> Effects Model (Cmd Msg)
init flags =
    let
        (joinModel, joinEffects) = Join.init

        (mapModel, mapEffects) = Map.init

        (keyboardModel, keyboardCmd) = Keyboard.init
    in
        Effects.init {
            state = GameState.Pending,
            address = flags.address,
            keyboardModel = keyboardModel,
            joinModel = joinModel,
            mapModel = mapModel
        }
        [Cmd.map KeyboardMsg keyboardCmd]
        `Effects.andThen` Effects.handle handleJoinEffect joinEffects
            `Effects.andThen` Effects.handle handleMapEffect mapEffects

-- Update

update : Msg -> Model -> Effects Model (Cmd Msg)
update msg model =
    case msg of

        UpdateGameState state ->
            Effects.return {model | state = state}

        KeyboardMsg keyMsg ->
            let
                (updatedKeyboardModel, keyboardCmd) =
                    Keyboard.update keyMsg model.keyboardModel

                (updatedMapModel, mapEffects) =
                    Map.update (Map.KeyboardMsg updatedKeyboardModel) model.mapModel
            in
                Effects.init {model |
                    keyboardModel = updatedKeyboardModel,
                    mapModel = updatedMapModel
                } [Cmd.map KeyboardMsg keyboardCmd]
                    `Effects.andThen` Effects.handle handleMapEffect mapEffects

        JoinMsg sub ->
            let
                (updateJoinModel, joinEffects) =
                    Join.update sub model.joinModel
            in
                Effects.return {model | joinModel = updateJoinModel}
                    `Effects.andThen` Effects.handle handleJoinEffect joinEffects

        MapMsg sub ->
            let
                (updateMapModel, mapEffects) =
                    Map.update sub model.mapModel
            in
                Effects.return {model | mapModel = updateMapModel}
                    `Effects.andThen` Effects.handle handleMapEffect mapEffects

        PerformCmd cmd ->
            Effects.init model [cmd]

        WsReceiveMessage str ->
            case decodeString message str of
                Ok message ->
                    onWsReceiveMessage message model
                Err reason ->
                    Debug.crash reason
                    -- TODO handle error
                    -- Effects.return model

        WsSendMessage str ->
            Effects.init model [WebSocket.send model.address str]

onWsReceiveMessage : Message -> Model -> Effects Model (Cmd Msg)
onWsReceiveMessage message model =
    case message of

        JoinResp joinResp ->
            update (JoinMsg (Join.OnJoinResponse joinResp)) model

        GameEv gameEv ->
            -- TODO handle game event
            Effects.return model

handleJoinEffect : Effects.Handler Join.Effect Model (Cmd Msg)
handleJoinEffect effect model =
    case effect of

        Join.UpdateGameState state ->
            update (UpdateGameState state) model

        Join.WsSendMessage str ->
            update (WsSendMessage str) model

handleMapEffect : Effects.Handler Map.Effect Model (Cmd Msg)
handleMapEffect effect model =
    case effect of

        Map.PerformCmd mapCmdMsg ->
            let
                cmdMsg = Cmd.map MapMsg mapCmdMsg
            in
                update (PerformCmd cmdMsg) model

        Map.NoOp ->
            Effects.return model

-- Subscriptions

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [
        WebSocket.listen model.address WsReceiveMessage,
        Sub.map KeyboardMsg Keyboard.subscriptions
    ]

-- View

view : Model -> Html Msg
view model =
    let
        body =
            case model.state of

                GameState.Joining ->
                    App.map JoinMsg <| Join.view model.joinModel

                GameState.Pending ->
                    App.map MapMsg <| Map.view model.mapModel

                GameState.Started ->
                    -- TODO create map view
                    div [] []

    in
        div [class "game-content is-full-width"] [
            body
        ]

-- Main

main : Program Flags
main =
    App.programWithFlags {
        init = \flags ->
                    let
                        (model, effects) = init flags
                    in
                        (model, effects) |> Effects.toCmd,
        view = view,
        update = \msg model -> update msg model |> Effects.toCmd,
        subscriptions = subscriptions
    }
