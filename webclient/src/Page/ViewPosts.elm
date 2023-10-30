module Page.ViewPosts exposing (Model, Msg, init, update, view)

import Html exposing (..)
import Http exposing (Error(..))
import Post exposing (Post, fetchPosts)
import Task
import Time exposing (Month(..))
import Url exposing (Protocol(..))


type alias Model =
    { posts : Resource String (List Post)
    , timezone : Resource () Time.Zone
    }


type Resource err a
    = Loading
    | Failed err
    | Loaded a


type Msg
    = GotPosts (Result Http.Error (List Post))
    | GotTimeZone (Result () Time.Zone)


init : String -> ( Model, Cmd Msg )
init apiKey =
    ( { posts = Loading, timezone = Loading }
    , Cmd.batch [ fetchPosts apiKey GotPosts, Task.attempt GotTimeZone Time.here ]
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotTimeZone (Ok zone) ->
            ( { model | timezone = Loaded zone }, Cmd.none )

        GotTimeZone (Err ()) ->
            ( { model | timezone = Failed () }, Cmd.none )

        GotPosts (Ok posts) ->
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


view : Model -> Html Msg
view model =
    case Debug.log "view posts" model.posts of
        Loading ->
            viewLoading

        Failed errMsg ->
            viewFailed errMsg

        Loaded posts ->
            viewPosts posts model.timezone


viewLoading : Html Msg
viewLoading =
    text "Fetching Posts..."


viewFailed : String -> Html Msg
viewFailed err =
    div []
        [ h2 [] [ text "Failed to fetch posts. " ]
        , text err
        ]


viewPosts : List Post -> Resource () Time.Zone -> Html Msg
viewPosts posts zone =
    if List.length posts == 0 then
        text "You have no posts"

    else
        table [] <| List.map (viewPost zone) posts


viewPost : Resource () Time.Zone -> Post -> Html Msg
viewPost zone post =
    tr []
        [ td [] [ text <| formatDate zone post.published_at ]
        , td [] [ text post.title ]
        ]


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
