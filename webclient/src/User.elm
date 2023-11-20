module User exposing (User, registerUser)

import ApiUrl exposing (apiBaseUrl)
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
        |> required "apikey" string



-- registerUserDataEncoder : Encoder RegisterUserData


registerUser : String -> (Result Http.Error User -> msg) -> Cmd msg
registerUser name toMsg =
    Http.post
        { url = apiBaseUrl ++ "/v1/users"
        , body = stringBody "application/json" ("{\"name\": \"" ++ name ++ "\"}")
        , expect = Http.expectJson toMsg userDecoder
        }
