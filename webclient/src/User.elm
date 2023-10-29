module User exposing (User, registerUser)

import Http exposing (stringBody)
import Json.Decode as Decode exposing (Decoder, string)
import Json.Decode.Pipeline exposing (hardcoded, optional, required)



-- import Json.Encode as Encode exposing (Encoder)


type alias User =
    { id : String
    , apiKey : String
    }


userDecoder : Decoder User
userDecoder =
    Decode.succeed User
        |> required "id" string
        |> required "api_key" string


type alias RegisterUserData =
    { name : String }



-- registerUserDataEncoder : Encoder RegisterUserData


registerUser : String -> (Result Http.Error User -> msg) -> Cmd msg
registerUser name toMsg =
    Http.post
        { url = "/v1/users"
        , body = stringBody "application/json" ("{\"name\": \"" ++ name ++ "\"}")
        , expect = Http.expectJson toMsg userDecoder
        }
