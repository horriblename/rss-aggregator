module User exposing (User, UserTokens, loginUser, registerUser)

import ApiUrl exposing (apiBaseUrl)
import Common exposing (ApiRequestError, expectApiJson)
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


type alias UserTokens =
    { id : String
    , accessToken : String
    , refreshToken : String
    }


userTokensDecoder : Decoder UserTokens
userTokensDecoder =
    Decode.succeed UserTokens
        |> required "id" string
        |> required "access_token" string
        |> required "refresh_token" string



-- -- Update this function's type signature accordingly
-- expectStringDetailed : (Result ErrorDetailed ( Metadata, String ) -> msg) -> Expect msg
-- expectStringDetailed msg =
-- Http.expectStringResponse msg convertResponseString


loginUser : RegisterData -> (Result ApiRequestError UserTokens -> msg) -> Cmd msg
loginUser loginData toMsg =
    Http.post
        { url = apiBaseUrl ++ "/v1/login"
        , body = jsonBody (encodeRegisterData loginData)
        , expect = expectApiJson toMsg userTokensDecoder
        }
