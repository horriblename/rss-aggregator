module Page.ViewPosts exposing (Model, Msg, init, update, view)

import Common exposing (Resource(..))
import Html exposing (..)
import Html.Attributes exposing (disabled, style)
import Html.Parser exposing (Node(..))
import Html.Parser.Util
import Http exposing (Error(..))
import Material.Card as Card
import Material.LayoutGrid as Grid
import Post exposing (Post, fetchPosts)
import Task
import Time exposing (Month(..))
import Url exposing (Protocol(..))


type alias Model =
    { posts : Resource String (List Post)
    , timezone : Resource () Time.Zone
    , waitingMorePosts : Bool
    , apiKey : String
    }


type Msg
    = GotPosts (Result Http.Error (List Post))
    | GotTimeZone (Result () Time.Zone)
    | FetchMorePosts


init : String -> ( Model, Cmd Msg )
init apiKey =
    ( { posts = Loading, timezone = Loading, waitingMorePosts = False, apiKey = apiKey }
    , Cmd.batch [ fetchPosts apiKey 0 GotPosts, Task.attempt GotTimeZone Time.here ]
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotTimeZone (Ok zone) ->
            ( { model | timezone = Loaded zone }, Cmd.none )

        GotTimeZone (Err ()) ->
            ( { model | timezone = Failed () }, Cmd.none )

        GotPosts (Ok posts) ->
            case model.posts of
                Loaded old ->
                    ( { model | posts = Loaded (old ++ posts) }, Cmd.none )

                _ ->
                    ( { model | posts = Loaded posts }, Cmd.none )

        GotPosts (Err err) ->
            let
                errMsg =
                    case err of
                        Timeout ->
                            "Timeout: try again later."

                        NetworkError ->
                            "Unable to reach the server, check your network connection."

                        BadStatus status ->
                            "Couldn't fetch posts, Status code " ++ String.fromInt status

                        BadBody e ->
                            "Something went wrong: " ++ e

                        BadUrl e ->
                            "Bad URL: " ++ e
            in
            ( { model | posts = Failed errMsg }, Cmd.none )

        FetchMorePosts ->
            case model.posts of
                Loaded posts ->
                    ( { model | waitingMorePosts = True }
                    , fetchPosts model.apiKey (List.length posts + 1) GotPosts
                    )

                _ ->
                    ( model, Cmd.none )


view : Model -> Html Msg
view model =
    case model.posts of
        Loading ->
            viewLoading

        Failed errMsg ->
            viewFailed errMsg

        Loaded posts ->
            viewPosts posts model


viewLoading : Html Msg
viewLoading =
    text "Fetching Posts..."


viewFailed : String -> Html Msg
viewFailed err =
    div []
        [ h2 [] [ text "Failed to fetch posts. " ]
        , text err
        ]


viewPosts : List Post -> Model -> Html Msg
viewPosts posts model =
    if List.length posts == 0 then
        text "You have no posts"

    else
        Grid.layoutGrid []
            [ Grid.inner [] <|
                List.map (viewPost model.timezone) posts
                    ++ [ viewMore model.waitingMorePosts ]
            ]


viewPost : Resource () Time.Zone -> Post -> Html Msg
viewPost zone post =
    let
        imageBlock =
            case post.media of
                Just { url, mimetype } ->
                    case getMimeRoot mimetype of
                        "image" ->
                            Just <| Card.sixteenToNineMedia [] url

                        _ ->
                            Nothing

                _ ->
                    Nothing

        titleBlock =
            Card.block <|
                Html.div []
                    [ Html.h2 [] [ text post.title ]
                    , Html.p [ style "overflow" "fade", style "white-space" "nowrap" ]
                        [ Html.i []
                            [ span [] [ text <| formatDate zone post.published_at ]
                            , span [] [ text <| " | by " ++ post.source.name ]
                            ]
                        ]
                    ]

        bodyHtml =
            case Html.Parser.run (Maybe.withDefault "" post.description) of
                Ok nodes ->
                    Html.Parser.Util.toVirtualDom <| sanitizeDescription nodes

                Err _ ->
                    [ text <| Maybe.withDefault "" post.description ]

        bodyBlock =
            Card.block <|
                Html.div []
                    [ Html.p [] bodyHtml ]

        blocks =
            case imageBlock of
                Just block ->
                    ( block, [ titleBlock, bodyBlock ] )

                Nothing ->
                    ( titleBlock, [ bodyBlock ] )
    in
    Grid.cell []
        [ Card.card (Card.config |> Card.setHref (Just post.url))
            { blocks = blocks
            , actions = Nothing
            }
        ]


viewMore : Bool -> Html Msg
viewMore fetching =
    Grid.cell []
        [ Card.card
            (Card.config
                |> Card.setOnClick
                    FetchMorePosts
                |> Card.setAttributes
                    [ disabled fetching
                    , style "text-align" "center"
                    ]
            )
            { blocks = ( Card.block (h2 [] [ text "See More" ]), [] )
            , actions = Nothing
            }
        ]


getMimeRoot : String -> String
getMimeRoot mimetype =
    case String.split "/" mimetype of
        root :: _ ->
            root

        -- unreachable
        _ ->
            ""


sanitizeDescription : List Html.Parser.Node -> List Html.Parser.Node
sanitizeDescription nodes =
    List.filterMap
        (\node ->
            case node of
                Element "script" _ _ ->
                    Nothing

                -- html-parser does not support svg, but, just in case
                Element "svg" _ _ ->
                    Nothing

                Element tag attr children ->
                    Just <| Element tag attr (sanitizeDescription children)

                a ->
                    Just a
        )
        nodes


formatDate : Resource () Time.Zone -> Time.Posix -> String
formatDate zone time =
    let
        timezone =
            case zone of
                Loaded tz ->
                    tz

                _ ->
                    Time.utc

        day =
            Time.toDay timezone time |> String.fromInt

        year =
            Time.toYear timezone time |> String.fromInt

        month =
            case Time.toMonth timezone time of
                Jan ->
                    "Jan"

                Feb ->
                    "Feb"

                Mar ->
                    "Mar"

                Apr ->
                    "Apr"

                May ->
                    "May"

                Jun ->
                    "Jun"

                Jul ->
                    "Jul"

                Aug ->
                    "Aug"

                Sep ->
                    "Sep"

                Oct ->
                    "Oct"

                Nov ->
                    "Nov"

                Dec ->
                    "Dec"
    in
    day ++ " " ++ month ++ " " ++ year
