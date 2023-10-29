module Page.Login exposing (Model, Msg, OutMsg(..), init, update, view)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import User exposing (User, registerUser)


type alias Model =
    { name : String
    , error : Maybe String
    }


type Msg
    = OnInputName String
    | Submit
    | LoginResult (Result Http.Error User)


type OutMsg
    = LoggedIn { apiKey : String }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { name = "", error = Nothing }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg, Maybe OutMsg )
update msg model =
    case msg of
        OnInputName name ->
            ( { model | name = name }, Cmd.none, Nothing )

        Submit ->
            ( model, registerUser model.name LoginResult, Nothing )

        LoginResult (Ok user) ->
            ( model, Cmd.none, Just <| LoggedIn { apiKey = user.apiKey } )

        LoginResult (Err (Http.BadStatus status)) ->
            ( { model | error = Just <| "Something went wrong: status code " ++ String.fromInt status }, Cmd.none, Nothing )

        LoginResult (Err _) ->
            ( { model | error = Just "Something went wrong" }, Cmd.none, Nothing )


view : Model -> Html Msg
view model =
    div []
        [ text "Username"
        , div [] [ viewError model.error ]
        , input [ type_ "text", onInput OnInputName ] []
        , button [ placeholder "John", onClick Submit ] []
        ]


viewError : Maybe String -> Html Msg
viewError errMsg =
    case errMsg of
        Just msg ->
            text msg

        Nothing ->
            text ""
