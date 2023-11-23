module User exposing (User, registerUser)

import ApiUrl exposing (apiBaseUrl)
import Http exposing (jsonBody)
import Json.Decode as Decode exposing (Decoder, string)
import Json.Decode.Pipeline exposing (required)
import Json.Encode as Encode



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


type alias RegisterData =
    { name : String, password : String }


encodeRegisterData : RegisterData -> Encode.Value
encodeRegisterData data =
    Encode.object
        [ ( "name", Encode.string data.name )
        , ( "password", Encode.string data.password )
        ]


registerUser : RegisterData -> (Result Http.Error User -> msg) -> Cmd msg
registerUser regData toMsg =
    Http.post
        { url = apiBaseUrl ++ "/v1/users"
        , body = jsonBody (encodeRegisterData regData)
        , expect = Http.expectJson toMsg userDecoder
        }
