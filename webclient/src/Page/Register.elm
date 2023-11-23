module Page.Register exposing (Model, Msg, OutMsg(..), init, update, view)

import Common exposing (Resource(..), errorBox, padContent)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Material.Button as Button
import Material.Elevation as Elevation
import Material.TextField as TextField
import User exposing (User, registerUser)


type alias Model =
    { name : String
    , password : String
    , passwordConfirm : String
    , submitStatus : Maybe (Resource String ())
    }


type Msg
    = OnInputName String
    | OnInputPassword String
    | OnInputPasswordConfirm String
    | Submit
    | RegisterResult (Result Http.Error User)


type OutMsg
    = RegisterSuccess


init : () -> ( Model, Cmd Msg )
init _ =
    ( { name = "", password = "", passwordConfirm = "", submitStatus = Nothing }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg, Maybe OutMsg )
update msg model =
    case msg of
        OnInputName name ->
            ( { model | name = name }, Cmd.none, Nothing )

        OnInputPassword pw ->
            ( { model | password = pw }, Cmd.none, Nothing )

        OnInputPasswordConfirm pw ->
            ( { model | passwordConfirm = pw }, Cmd.none, Nothing )

        Submit ->
            if model.password == model.passwordConfirm then
                ( { model | submitStatus = Just Loading }
                , registerUser { name = model.name, password = model.password } RegisterResult
                , Nothing
                )

            else
                ( { model | submitStatus = Just (Failed "Passwords do not match.") }, Cmd.none, Nothing )

        RegisterResult (Ok _) ->
            ( model, Cmd.none, Just <| RegisterSuccess )

        RegisterResult (Err (Http.BadStatus status)) ->
            ( { model | submitStatus = Just <| Failed <| "Something went wrong: status code " ++ String.fromInt status }, Cmd.none, Nothing )

        RegisterResult (Err _) ->
            ( { model | submitStatus = Just <| Failed "Something went wrong" }, Cmd.none, Nothing )


view : Model -> Html Msg
view model =
    let
        wrapDiv el =
            div [ padContent ] [ el ]

        disableButton =
            case model.submitStatus of
                Just Loading ->
                    True

                Just (Loaded _) ->
                    True

                _ ->
                    False
    in
    Html.form [ onSubmit Submit, Elevation.z12, padContent ]
        [ div [ padContent ] [ h1 [] [ text "Login" ] ]
        , viewError model.submitStatus
        , div []
            [ wrapDiv <|
                TextField.filled
                    (TextField.config
                        |> TextField.setLabel (Just "Name")
                        |> TextField.setOnInput OnInputName
                        |> TextField.setPlaceholder (Just "John")
                    )
            , wrapDiv <|
                TextField.filled
                    (TextField.config
                        |> TextField.setLabel (Just "Password")
                        |> TextField.setType (Just "password")
                        |> TextField.setOnInput OnInputPassword
                    )
            , wrapDiv <|
                TextField.filled
                    (TextField.config
                        |> TextField.setLabel (Just "Password Confirm")
                        |> TextField.setType (Just "password")
                        |> TextField.setOnInput OnInputPasswordConfirm
                    )
            ]
        , div [ padContent, style "text-align" "right" ]
            [ Button.raised
                (Button.config
                    |> Button.setAttributes [ type_ "submit" ]
                    |> Button.setDisabled disableButton
                )
                "Submit"
            ]
        ]


viewError : Maybe (Resource String ()) -> Html Msg
viewError res =
    case res of
        Just (Failed err) ->
            errorBox (Just err)

        _ ->
            text ""
