module Page.NewFeed exposing (Model, Msg, OutMsg(..), init, update, view)

import Common exposing (Resource(..), errorBox, padContent)
import Feed exposing (Feed, createFeed)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Material.Button as Button
import Material.Elevation as Elevation
import Material.TextField as TextField


type alias Model =
    { name : String
    , url : String
    , apiKey : String
    , createResult : Maybe (Resource String ())
    }


type Msg
    = OnInputName String
    | OnInputUrl String
    | Submit
    | CreateResult (Result Http.Error Feed)


type OutMsg
    = CreatedFeed Feed


init : String -> ( Model, Cmd Msg )
init apiKey =
    ( { name = "", url = "", apiKey = apiKey, createResult = Nothing }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg, Maybe OutMsg )
update msg model =
    case msg of
        OnInputName name ->
            ( { model | name = name }, Cmd.none, Nothing )

        OnInputUrl url ->
            ( { model | url = url }, Cmd.none, Nothing )

        Submit ->
            ( model, createFeed model.apiKey CreateResult { name = model.name, url = model.url }, Nothing )

        CreateResult (Ok feed) ->
            ( { model | createResult = Just (Loaded ()) }, Cmd.none, Just (CreatedFeed feed) )

        CreateResult (Err e) ->
            let
                err =
                    case e of
                        Http.BadUrl _ ->
                            "Bad URL"

                        Http.BadBody _ ->
                            "Got Bad Body"

                        Http.BadStatus status ->
                            "Bad Status: " ++ String.fromInt status

                        Http.Timeout ->
                            "Timed out"

                        Http.NetworkError ->
                            "Network Error."
            in
            ( { model | createResult = Just <| Failed ("An error occured, try again later. " ++ err) }
            , Cmd.none
            , Nothing
            )


view : Model -> Html Msg
view model =
    let
        textField label placeholder toMsg =
            div [ padContent ]
                [ TextField.filled
                    (TextField.config
                        |> TextField.setPlaceholder (Just placeholder)
                        |> TextField.setLabel (Just label)
                        |> TextField.setOnInput toMsg
                     -- |> TextField.setAttributes [ style "margin" "0 auto" ]
                    )
                ]

        errMsg =
            case model.createResult of
                Just (Failed err) ->
                    errorBox (Just err)

                _ ->
                    text ""

        disableButton =
            case model.createResult of
                Just Loading ->
                    True

                Just (Loaded _) ->
                    True

                _ ->
                    False
    in
    Html.form [ onSubmit Submit, style "padding" "1rem" ]
        [ errMsg
        , textField "Name" "Jame's Blog" OnInputName
        , textField "URL" "www.example.com/rss.xml" OnInputUrl
        , div [ padContent, style "text-align" "right" ]
            [ Button.raised
                (Button.config
                    |> Button.setAttributes [ type_ "submit" ]
                    |> Button.setDisabled disableButton
                )
                "Submit"
            ]
        ]
