module Drawer exposing (Model, Msg(..), initialModel, scrim, update, view)

import Html exposing (Html)
import Html.Attributes exposing (style)
import Material.Button as Button
import Material.Drawer.Modal as ModalDrawer
import Material.Icon as Icon
import Material.IconButton as IconButton
import Material.List as List
import Material.List.Item as ListItem


type alias Model =
    { open : Bool
    , selectedIndex : Int
    }


type Msg
    = OpenDrawer
    | CloseDrawer
    | SetSelectedIndex Int


initialModel : Model
initialModel =
    { open = False, selectedIndex = 0 }


update : Msg -> Model -> Model
update msg model =
    case msg of
        OpenDrawer ->
            { model | open = True }

        CloseDrawer ->
            { model | open = False }

        SetSelectedIndex index ->
            { model | selectedIndex = index }



-- This modal drawer must be immediately followed by `scrim`


view : Model -> Html Msg
view model =
    let
        listItem icon label url =
            ListItem.listItem
                (ListItem.config
                    |> ListItem.setHref (Just url)
                    |> ListItem.setOnClick CloseDrawer
                )
                [ ListItem.graphic [] [ Icon.icon [] icon ]
                , Html.text label
                ]
    in
    ModalDrawer.drawer
        (ModalDrawer.config
            |> ModalDrawer.setOpen model.open
            |> ModalDrawer.setOnClose CloseDrawer
            |> ModalDrawer.setAttributes [ style "padding-top" "0.5rem" ]
        )
        [ IconButton.iconButton
            (IconButton.config
                |> IconButton.setOnClick CloseDrawer
                |> IconButton.setAttributes [ style "padding-left" "1rem" ]
            )
            (IconButton.icon "arrow_back")
        , List.list
            List.config
            (listItem "home" "Home" "/")
            [ listItem "feed" "Feeds" "/feeds" ]
        ]


scrim : Html msg
scrim =
    ModalDrawer.scrim [] []
