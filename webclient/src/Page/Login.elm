module Page.Login exposing (Model, Msg, OutMsg(..), init, update, view)

import Common exposing (Resource(..))
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Material.Button as Button
import Material.TextField as TextField
import Material.Typography as Typography
import User exposing (User, registerUser)


type alias Model =
    { name : String
    , submitStatus : Maybe (Resource String ())
    }


type Msg
    = OnInputName String
    | Submit
    | LoginResult (Result Http.Error User)


type OutMsg
    = LoggedIn { apiKey : String }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { name = "", submitStatus = Nothing }, Cmd.none )


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
            ( { model | submitStatus = Just <| Failed <| "Something went wrong: status code " ++ String.fromInt status }, Cmd.none, Nothing )

        LoginResult (Err _) ->
            ( { model | submitStatus = Just <| Failed "Something went wrong" }, Cmd.none, Nothing )


view : Model -> Html Msg
view model =
    Html.form [ onSubmit Submit, class "mdc-layout-grid", Typography.typography ]
        [ viewError model.submitStatus
        , div []
            [ TextField.filled
                (TextField.config
                    |> TextField.setLabel (Just "Name")
                    |> TextField.setOnInput OnInputName
                    |> TextField.setPlaceholder (Just "John")
                )
            ]
        , div []
            [ Button.raised
                (Button.config
                    |> Button.setAttributes [ type_ "submit" ]
                    |> Button.setDisabled
                        (case model.submitStatus of
                            Just Loading ->
                                True

                            Just (Loaded _) ->
                                True

                            _ ->
                                False
                        )
                )
                "Submit"
            ]
        ]


viewError : Maybe (Resource String ()) -> Html Msg
viewError res =
    case res of
        Just (Failed err) ->
            text err

        _ ->
            text ""
