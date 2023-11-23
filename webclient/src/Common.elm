module Common exposing (ApiRequestError(..), Resource(..), errorBox, expectApiJson, padContent, refreshAccessToken)

import ApiUrl exposing (apiBaseUrl)
import Html exposing (Html)
import Html.Attributes exposing (style)
import Http exposing (header)
import Json.Decode as Decode exposing (Decoder, string)
import Json.Decode.Pipeline exposing (required)


type Resource err a
    = Loading
    | Failed err
    | Loaded a


errorBox : Maybe String -> Html msg
errorBox err =
    case err of
        Just errMsg ->
            Html.div [ padContent, style "color" "red" ] [ Html.text errMsg ]

        Nothing ->
            Html.text ""


padContent : Html.Attribute msg
padContent =
    style "padding" "1rem"


type alias ErrorMsg =
    { error : String }


apiErrorDecoder : Decoder ErrorMsg
apiErrorDecoder =
    Decode.succeed ErrorMsg
        |> required "error" string


type ApiRequestError
    = Unhandled Http.Error
    | BadStatus Int String
    | BadStatusAndBody Int


expectApiJson : (Result ApiRequestError a -> msg) -> Decode.Decoder a -> Http.Expect msg
expectApiJson toMsg decoder =
    Http.expectStringResponse toMsg <|
        \response ->
            case response of
                Http.BadUrl_ url ->
                    Err (Unhandled <| Http.BadUrl url)

                Http.Timeout_ ->
                    Err <| Unhandled <| Http.Timeout

                Http.NetworkError_ ->
                    Err <| Unhandled <| Http.NetworkError

                Http.BadStatus_ metadata body ->
                    case Decode.decodeString apiErrorDecoder body of
                        Ok value ->
                            Err <| BadStatus metadata.statusCode value.error

                        Err _ ->
                            Err <| BadStatusAndBody metadata.statusCode

                Http.GoodStatus_ _ body ->
                    case Decode.decodeString decoder body of
                        Ok value ->
                            Ok value

                        Err err ->
                            Err <| Unhandled <| Http.BadBody (Decode.errorToString err)


type alias AccessToken =
    { token : String }


refreshedAccessTokenDecoder : Decoder String
refreshedAccessTokenDecoder =
    Decode.succeed AccessToken
        |> required "token" string
        |> Decode.map (\tok -> tok.token)


refreshAccessToken : String -> (Result ApiRequestError String -> msg) -> Cmd msg
refreshAccessToken refreshToken toMsg =
    Http.request
        { method = "POST"
        , headers = [ header "Authorization" <| "Bearer " ++ refreshToken ]
        , url = apiBaseUrl ++ "/v1/refresh"
        , body = Http.emptyBody
        , expect = expectApiJson toMsg refreshedAccessTokenDecoder
        , timeout = Nothing
        , tracker = Nothing
        }
