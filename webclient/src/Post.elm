module Post exposing (Post, fetchPosts)

-- import Json.Decode as D
-- import Json.Encode as E

import Http exposing (header)
import Json.Decode as Decode exposing (Decoder, int, list, map, maybe, string)
import Json.Decode.Pipeline exposing (required)
import Json.Encode as Encode
import Route exposing (apiBaseUrl)
import Time exposing (millisToPosix)


type alias Post =
    { id : String
    , created_at : Time.Posix
    , updated_at : Time.Posix
    , title : String
    , url : String
    , description : Maybe String
    , published_at : Time.Posix
    , feed_id : String
    }


postDecoder : Decoder Post
postDecoder =
    Decode.succeed Post
        |> required "id" string
        |> required "created_at" (map millisToPosix int)
        |> required "updated_at" (map millisToPosix int)
        |> required "title" string
        |> required "url" string
        |> required "description" (maybe string)
        |> required "published_at" (map millisToPosix int)
        |> required "feed_id" string


type alias FetchPostsParams =
    { limit : Maybe Int }


encodeFetchPostsParam : FetchPostsParams -> Encode.Value
encodeFetchPostsParam params =
    case params.limit of
        Nothing ->
            Encode.object []

        Just limit ->
            Encode.object [ ( "limit", Encode.int limit ) ]


fetchPosts : String -> (Result Http.Error (List Post) -> msg) -> Cmd msg
fetchPosts apiKey toMsg =
    Http.request
        { method = "GET"
        , headers = [ header "Authorization" <| "ApiKey " ++ apiKey ]
        , url = apiBaseUrl ++ "/v1/posts"
        , body = Http.stringBody "text/plain" "hello"
        , expect = Http.expectJson toMsg (list postDecoder)
        , timeout = Nothing
        , tracker = Nothing
        }
