module Feed exposing (Feed, UUID, createFeed, fetchFeeds, fetchFollows, followFeed)

import Http exposing (header)
import Json.Decode as Decode exposing (Decoder, list, string)
import Json.Decode.Pipeline exposing (required)
import Json.Encode as Encode
import Route exposing (apiBaseUrl)


type alias Feed =
    { id : String
    , name : String
    , url : String
    }


feedDecoder : Decoder Feed
feedDecoder =
    Decode.succeed Feed
        |> required "id" string
        |> required "name" string
        |> required "url" string


fetchFeeds : String -> (Result Http.Error (List Feed) -> msg) -> Cmd msg
fetchFeeds apiKey toMsg =
    Http.request
        { method = "GET"
        , headers = []
        , url = apiBaseUrl ++ "/v1/feeds"
        , body = Http.emptyBody
        , expect = Http.expectJson toMsg (list feedDecoder)
        , timeout = Nothing
        , tracker = Nothing
        }


type alias CreateFeedParams =
    { name : String, url : String }


encodeCreateFeedParams : { name : String, url : String } -> Encode.Value
encodeCreateFeedParams params =
    Encode.object
        [ ( "name", Encode.string params.name )
        , ( "url", Encode.string params.url )
        ]


createFeed : String -> (Result Http.Error Feed -> msg) -> CreateFeedParams -> Cmd msg
createFeed apiKey toMsg params =
    Http.request
        { method = "POST"
        , headers = [ header "Authorization" <| "ApiKey " ++ apiKey ]
        , url = apiBaseUrl ++ "/v1/feeds"
        , body = Http.jsonBody (encodeCreateFeedParams params)
        , expect = Http.expectJson toMsg feedDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


type alias UUID =
    String



-- the API returns more data but this is all we need


type alias FetchFollows =
    { id : String }



-- fetches a list of follows as UUIDs


fetchFollows : String -> (Result Http.Error (List UUID) -> msg) -> Cmd msg
fetchFollows apiKey toMsg =
    let
        decoder =
            Decode.succeed FetchFollows
                |> required "id" string
    in
    Http.request
        { method = "GET"
        , headers = [ header "Authorization" <| "ApiKey " ++ apiKey ]
        , url = apiBaseUrl ++ "/v1/feeds"
        , body = Http.emptyBody
        , expect = Http.expectJson toMsg (Decode.map (List.map .id) (list decoder))
        , timeout = Nothing
        , tracker = Nothing
        }


followFeed : String -> String -> (Result Http.Error () -> msg) -> Cmd msg
followFeed apiKey feedID toMsg =
    let
        params =
            Encode.object [ ( "feed_id", Encode.string feedID ) ]
    in
    Http.request
        { method = "POST"
        , headers = [ header "Authorization" <| "ApiKey " ++ apiKey ]
        , url = apiBaseUrl ++ "/v1/feed_follows"
        , body = Http.jsonBody params
        , expect = Http.expectWhatever toMsg
        , timeout = Nothing
        , tracker = Nothing
        }
