module Post exposing (Post, fetchPosts)

-- import Json.Decode as D
-- import Json.Encode as E

import Http exposing (header)
import Iso8601
import Json.Decode as Decode exposing (Decoder, andThen, list, map, maybe, string)
import Json.Decode.Pipeline exposing (optional, required)
import Route exposing (apiBaseUrl)
import Time


type alias Post =
    { id : String
    , created_at : Time.Posix
    , updated_at : Time.Posix
    , title : String
    , url : String
    , description : Maybe String
    , published_at : Time.Posix
    , feed_id : String
    , media : Maybe Media
    }


type alias Media =
    { url : String
    , mimetype : String
    }


mediaDecoder : Decoder Media
mediaDecoder =
    Decode.succeed Media
        |> required "url" string
        |> required "mimetype" string


postDecoder : Decoder Post
postDecoder =
    Decode.succeed Post
        |> required "id" string
        |> required "created_at" (andThen (\_ -> Iso8601.decoder) string)
        |> required "updated_at" (andThen (\_ -> Iso8601.decoder) string)
        |> required "title" string
        |> required "url" string
        |> optional "description" (maybe string) Nothing
        |> required "published_at" (andThen (\_ -> Iso8601.decoder) string)
        |> required "feed_id" string
        |> optional "media" (maybe mediaDecoder) Nothing


fetchPosts : String -> (Result Http.Error (List Post) -> msg) -> Cmd msg
fetchPosts apiKey toMsg =
    Http.request
        { method = "GET"
        , headers = [ header "Authorization" <| "ApiKey " ++ apiKey ]
        , url = apiBaseUrl ++ "/v1/posts"
        , body = Http.emptyBody
        , expect = Http.expectJson toMsg (list postDecoder)
        , timeout = Nothing
        , tracker = Nothing
        }
