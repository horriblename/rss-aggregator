module Page.ViewFeeds exposing (Model, Msg, init, update, view)

import Common exposing (Resource(..))
import Feed exposing (Feed, fetchFeeds)
import Html exposing (..)
import Http exposing (Error(..))
import Url exposing (Protocol(..))


type alias Model =
    { feeds : Resource String (List Feed)
    }


type Msg
    = GotFeeds (Result Http.Error (List Feed))


init : String -> ( Model, Cmd Msg )
init apiKey =
    ( { feeds = Loading }, fetchFeeds apiKey GotFeeds )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case Debug.log "viewfeeds.update" msg of
        GotFeeds (Ok feeds) ->
            ( { model | feeds = Loaded feeds }, Cmd.none )

        GotFeeds (Err err) ->
            let
                errMsg =
                    case err of
                        Timeout ->
                            "Timeout: try again later."

                        NetworkError ->
                            "Unable to reach the server, check your network connection."

                        BadStatus status ->
                            "Couldn't fetch feeds, Status code " ++ String.fromInt status

                        _ ->
                            "Something went wrong: Please try again later."
            in
            ( { model | feeds = Failed errMsg }, Cmd.none )


view : Model -> Html Msg
view model =
    case Debug.log "view feeds" model.feeds of
        Loading ->
            viewLoading

        Failed errMsg ->
            viewFailed errMsg

        Loaded feeds ->
            viewFeeds feeds


viewLoading : Html Msg
viewLoading =
    text "Fetching Feeds..."


viewFailed : String -> Html Msg
viewFailed err =
    text <| "Failed to fetch feeds: " ++ err


viewFeeds : List Feed -> Html Msg
viewFeeds feeds =
    if List.length feeds == 0 then
        text "You have no Feeds"

    else
        table [] <| List.map viewFeed feeds


viewFeed : Feed -> Html Msg
viewFeed feed =
    tr []
        [ td [] [ text feed.url ]
        ]
