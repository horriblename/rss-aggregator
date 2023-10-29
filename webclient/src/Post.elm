module Post exposing (Post)

-- import Json.Decode as D
-- import Json.Encode as E

import Json.Decode as Decode exposing (Decoder, int, map, maybe, string)
import Json.Decode.Pipeline exposing (required)
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



-- ID          uuid.UUID `json:"
-- 	CreatedAt   time.Time `json:"
-- 	UpdatedAt   time.Time `json:"
-- 	Title       string    `json:"
-- 	Url         string    `json:"
-- 	Description string    `json:"
-- 	PublishedAt time.Time `json:"
-- 	FeedID      uuid.UUID `json:"


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
