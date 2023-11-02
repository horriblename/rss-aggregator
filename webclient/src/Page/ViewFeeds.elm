module Page.ViewFeeds exposing (Model, Msg, init, update, view)

import Common exposing (Resource(..))
import Dict exposing (Dict)
import Feed exposing (Feed, UUID, fetchFeeds, followFeed)
import Html exposing (..)
import Html.Attributes exposing (style)
import Html.Keyed as Keyed
import Html.Lazy exposing (lazy2)
import Http exposing (Error(..))
import Material.DataTable as DataTable
import Material.IconButton as IconButton
import Material.List as List_
import Material.List.Item as ListItem
import Url exposing (Protocol(..))


type alias Model =
    { apiKey : String
    , feeds : Resource String (Dict String Feed)
    , follows : Resource String (List UUID)
    }


type Msg
    = GotFeeds (Result Http.Error (List Feed))
    | GotFollows (Result Http.Error (List UUID))
    | FollowFeed { feedID : String }
    | FollowResult (Result Http.Error ())


type alias FeedFollow =
    { feed : Feed
    , follow : Bool
    }


init : String -> ( Model, Cmd Msg )
init apiKey =
    ( { apiKey = apiKey, feeds = Loading, follows = Loading }
    , Cmd.batch
        [ fetchFeeds apiKey GotFeeds
        , Feed.fetchFollows apiKey GotFollows
        ]
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case Debug.log "viewfeeds.update" msg of
        GotFeeds (Ok feeds) ->
            let
                dict =
                    Dict.fromList <|
                        List.map (\feed -> ( feed.id, feed )) feeds
            in
            ( { model | feeds = Loaded dict }, Cmd.none )

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

        GotFollows (Ok follows) ->
            ( { model | follows = Loaded follows }, Cmd.none )

        GotFollows (Err err) ->
            ( { model | follows = Failed (Debug.todo "") }, Cmd.none )

        FollowFeed { feedID } ->
            ( model, followFeed model.apiKey feedID FollowResult )

        FollowResult (Ok ()) ->
            Debug.todo ""

        FollowResult (Err a) ->
            Debug.todo ""


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


viewFeeds : Dict String Feed -> Html Msg
viewFeeds feeds =
    if Dict.isEmpty feeds then
        text "No Feeds Found"

    else
        Keyed.node "table" [ style "width" "100%" ] <|
            List.map (\feed -> ( feed.id, viewFeed feed )) (Dict.values feeds)



-- DataTable.dataTable
--     (DataTable.config
--         |> DataTable.setAttributes [ style "width" "100%" ]
--     )
--     { thead = []
--     , tbody =
--     }


viewFeed : Feed -> Html Msg
viewFeed feed =
    lazy2 Html.tr
        []
        [ Html.td [] [ text feed.url ]
        , Html.td []
            [ IconButton.iconButton
                (IconButton.config
                    |> IconButton.setOnClick (FollowFeed { feedID = feed.id })
                )
                (IconButton.icon "add")
            ]
        ]
