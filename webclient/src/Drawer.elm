module Drawer exposing (Model, Msg(..), initialModel, scrim, update, view)

import Html exposing (Html)
import Material.Button as Button
import Material.Drawer.Modal as ModalDrawer
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
            ListItem.listItem ListItem.config
                [ Button.text
                    (Button.config
                        |> Button.setHref (Just url)
                        |> Button.setIcon (Just (Button.icon icon))
                        |> Button.setOnClick CloseDrawer
                    )
                    label
                ]
    in
    ModalDrawer.drawer
        (ModalDrawer.config
            |> ModalDrawer.setOpen model.open
            |> ModalDrawer.setOnClose CloseDrawer
        )
        [ List.list
            List.config
            (listItem "home" "Home" "/")
            [ listItem "feeds" "Feeds" "/feeds" ]
        ]


scrim : Html msg
scrim =
    ModalDrawer.scrim [] []
