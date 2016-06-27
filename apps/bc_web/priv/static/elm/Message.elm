module Message exposing (..)

import Json.Decode exposing (..)

-- Model types

type alias Player = {
	id : Int
	handle : String
}

player : Decoder Player
player =
	object2 Player
		("id" := Int)
		("handle" := String)

-- GameEvent Types

type alias PlayerEvent = {
	eventType : String
	player : Player
}

playerEvent : Decoder GameEvent
playerEvent =
	object2 PlayerEvent
		("event_type" := string)
		("player" := player)

type alias GameStartedEvent = {
	eventType : String
	players : List Player
}

gameStartedEvent : Decoder GameEvent
gameStartedEvent =
	object2 GameStartedEvent
		("event_type" := string)
		("players" := list player)

type alias GameErrorEvent = {
	eventType : String
	reason : String
}

gameErrorEvent : Decoder GameEvent
gameErrorEvent =
	object2 GameErrorEvent
		("event_type" := string)
		("reason" := string)

-- Aggregate Types

type GameEvent =
	PlayerEvent |
	GameStartedEvent |
	GameErrorEvent

gameEventInfo : String -> Decoder GameEvent
gameEventInfo eventType =
	case eventType of
		"game_started" ->
			gameStartedEvent
		"game_error" ->
			gameErrorEvent
		_ ->
			playerEvent

gameEvent : Decoder GameEvent
gameEvent =
	at ["game_event", "event_type"] string `andThen` gameEventInfo

type Message =
	GameEvent

messageInfo : String -> Decoder Message
messageInfo messageType =
	case messageType of
		"game_event" ->
			gameEvent

message : Decoder Message
message =
	("type" := string) `andThen` messageInfo
