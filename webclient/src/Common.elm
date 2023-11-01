module Common exposing (Resource(..), errorBox, padContent)

import Html exposing (Html)
import Html.Attributes exposing (style)


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
