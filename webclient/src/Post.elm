module Post exposing (Post, fetchPosts)

import Http exposing (header)
import Iso8601
import Json.Decode as Decode exposing (Decoder, andThen, list, maybe, string)
import Json.Decode.Pipeline exposing (optional, required)
import Route exposing (apiBaseUrl)
import Time


type alias Post =
    { id : String
    , title : String
    , url : String
    , description : Maybe String
    , published_at : Time.Posix
    , feed_id : String
    , guid : Maybe String
    , media : Maybe Media
    , source : Source
    }


type alias Media =
    { url : String
    , mimetype : String
    }


type alias Source =
    { url : String
    , name : String
    }


mediaDecoder : Decoder Media
mediaDecoder =
    Decode.succeed Media
        |> required "url" string
        |> required "mimetype" string


sourceDecoder : Decoder Source
sourceDecoder =
    Decode.succeed Source
        |> required "url" string
        |> required "name" string


postDecoder : Decoder Post
postDecoder =
    Decode.succeed Post
        |> required "id" string
        |> required "title" string
        |> required "url" string
        |> optional "description" (maybe string) Nothing
        |> required "published_at" (andThen (\_ -> Iso8601.decoder) string)
        |> required "feed_id" string
        |> optional "guid" (maybe string) Nothing
        |> optional "media" (maybe mediaDecoder) Nothing
        |> required "source" sourceDecoder


fetchPosts : String -> Int -> (Result Http.Error (List Post) -> msg) -> Cmd msg
fetchPosts apiKey offset toMsg =
    Http.request
        { method = "GET"
        , headers = [ header "Authorization" <| "ApiKey " ++ apiKey ]
        , url = apiBaseUrl ++ "/v1/posts?limit=20&offset=" ++ String.fromInt offset
        , body = Http.emptyBody
        , expect = Http.expectJson toMsg (list postDecoder)
        , timeout = Nothing
        , tracker = Nothing
        }
