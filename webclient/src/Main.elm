port module Main exposing (main, storeApiKey)

-- import Browser.Navigation as Nav

import Browser exposing (Document, UrlRequest)
import Browser.Navigation as Nav
import Drawer
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Lazy as Lazy
import Material.Icon as Icon
import Material.IconButton as IconButton
import Material.TopAppBar as TopAppBar
import Material.Typography exposing (typography)
import Page.Login as LoginPage exposing (OutMsg(..))
import Page.NewFeed as NewFeedPage exposing (OutMsg(..))
import Page.ViewFeeds as FeedsPage
import Page.ViewPosts as PostsPage
import Platform.Cmd as Cmd
import Post exposing (Post)
import Route exposing (Route)
import Url exposing (Url)



-- MAIN


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- MODEL


type alias Model =
    { apiKey : Maybe String
    , posts : List Post
    , route : Route
    , page : Page
    , navKey : Nav.Key
    , drawer : Drawer.Model
    }


type Page
    = NotFoundPage
    | LoginPage LoginPage.Model
    | FeedsPage FeedsPage.Model
    | PostsPage PostsPage.Model
    | NewFeedPage NewFeedPage.Model


type alias Flags =
    { apiKey : Maybe String }


init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url navKey =
    let
        model =
            { apiKey = flags.apiKey
            , posts = []
            , route = Route.parseUrl (Debug.log "url" url)
            , page = NotFoundPage
            , navKey = navKey
            , drawer = Drawer.initialModel
            }
    in
    initCurrentPage ( model, Cmd.none )


initCurrentPage : ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
initCurrentPage ( model, exisitngCmds ) =
    let
        ( currentPage, mappedPageCmds ) =
            case model.route of
                Route.NotFound ->
                    ( NotFoundPage, Cmd.none )

                Route.Posts ->
                    initAuthedPage PostsPage.init model PostsPage PostsPageMsg

                Route.Login ->
                    let
                        ( pageModel, pageCmds ) =
                            LoginPage.init ()
                    in
                    ( LoginPage pageModel, Cmd.map LoginPageMsg pageCmds )

                Route.Feeds ->
                    initAuthedPage FeedsPage.init model FeedsPage FeedsPageMsg

                Route.NewFeed ->
                    initAuthedPage NewFeedPage.init model NewFeedPage NewFeedPageMsg
    in
    ( { model | page = Debug.log "currentPage" currentPage }
    , Cmd.batch [ exisitngCmds, mappedPageCmds ]
    )


type alias Init a model msg =
    a -> ( model, Cmd msg )


initAuthedPage : Init String model msg -> Model -> (model -> Page) -> (msg -> Msg) -> ( Page, Cmd Msg )
initAuthedPage pageInit model toModel toMsg =
    case model.apiKey of
        Nothing ->
            ( NotFoundPage, Nav.pushUrl model.navKey "/login" )

        Just apiKey ->
            let
                ( pageModel, pageCmds ) =
                    pageInit apiKey
            in
            ( toModel pageModel, Cmd.map toMsg pageCmds )



-- PORTS


port storeApiKey : String -> Cmd msg



-- UPDATE


type Msg
    = LoginPageMsg LoginPage.Msg
    | FeedsPageMsg FeedsPage.Msg
    | PostsPageMsg PostsPage.Msg
    | NewFeedPageMsg NewFeedPage.Msg
    | LinkClicked UrlRequest
    | UrlChanged Url
    | DrawerMsg Drawer.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.page ) of
        ( LinkClicked urlRequest, _ ) ->
            case urlRequest of
                Browser.Internal url ->
                    ( model
                    , Nav.pushUrl model.navKey (Url.toString url)
                    )

                Browser.External url ->
                    ( model, Nav.load url )

        ( UrlChanged url, _ ) ->
            let
                newRoute =
                    Route.parseUrl url
            in
            ( { model | route = newRoute }, Cmd.none )
                |> initCurrentPage

        ( DrawerMsg subMsg, _ ) ->
            ( { model | drawer = Drawer.update subMsg model.drawer }, Cmd.none )

        ( LoginPageMsg subMsg, LoginPage subModel ) ->
            let
                ( updatedPageModel, updatedCmd, outMsg ) =
                    LoginPage.update subMsg subModel

                updatedModel =
                    { model | page = LoginPage updatedPageModel }

                ( updatedSignalModel, moreCmd ) =
                    processSignal updatedModel (LoginPageSignal outMsg)
            in
            ( updatedSignalModel, Cmd.batch [ Cmd.map LoginPageMsg updatedCmd, moreCmd ] )

        ( FeedsPageMsg subMsg, FeedsPage subModel ) ->
            let
                ( updatedPageModel, updatedCmd ) =
                    FeedsPage.update subMsg subModel
            in
            ( { model | page = FeedsPage updatedPageModel }, Cmd.map FeedsPageMsg updatedCmd )

        ( PostsPageMsg subMsg, PostsPage subModel ) ->
            let
                ( updatedPageModel, updatedCmd ) =
                    PostsPage.update subMsg subModel
            in
            ( { model | page = PostsPage updatedPageModel }, Cmd.map PostsPageMsg updatedCmd )

        ( NewFeedPageMsg subMsg, NewFeedPage subModel ) ->
            let
                ( updatedPageModel, updatedCmd, outMsg ) =
                    NewFeedPage.update subMsg subModel

                updatedModel =
                    { model | page = NewFeedPage updatedPageModel }

                ( updatedSignalModel, moreCmd ) =
                    processSignal updatedModel (NewFeedPageSignal outMsg)
            in
            ( updatedSignalModel, Cmd.batch [ Cmd.map NewFeedPageMsg updatedCmd, moreCmd ] )

        ( _, _ ) ->
            ( model, Cmd.none )


type SignalFromChild
    = LoginPageSignal (Maybe LoginPage.OutMsg)
    | NewFeedPageSignal (Maybe NewFeedPage.OutMsg)


processSignal : Model -> SignalFromChild -> ( Model, Cmd Msg )
processSignal model signal =
    case signal of
        LoginPageSignal (Just (LoggedIn { apiKey })) ->
            ( { model | apiKey = Just apiKey }, Cmd.batch [ storeApiKey apiKey, Nav.pushUrl model.navKey "/" ] )

        NewFeedPageSignal (Just (CreatedFeed _)) ->
            ( model, Nav.pushUrl model.navKey "/" )

        _ ->
            ( model, Cmd.none )



-- VIEW


view : Model -> Document Msg
view model =
    { title = "RSS Aggregator"
    , body =
        [ Lazy.lazy2 Html.div
            (typography :: drawerFrameRoot)
            [ Html.map DrawerMsg <| Lazy.lazy Drawer.view model.drawer
            , Drawer.scrim
            , Html.div [ style "width" "100%" ]
                [ Lazy.lazy viewTopBar model.drawer.open
                , Html.div [ TopAppBar.fixedAdjust ] [ currentView model ]
                ]
            ]
        ]
    }


viewTopBar : Bool -> Html Msg
viewTopBar drawerIsOpen =
    TopAppBar.regular TopAppBar.config
        [ TopAppBar.row []
            [ TopAppBar.section [ TopAppBar.alignStart ]
                [ IconButton.iconButton
                    (IconButton.config
                        |> IconButton.setAttributes [ TopAppBar.navigationIcon ]
                        |> IconButton.setOnClick
                            (DrawerMsg
                                (if drawerIsOpen then
                                    Drawer.CloseDrawer

                                 else
                                    Drawer.OpenDrawer
                                )
                            )
                    )
                    (IconButton.icon "menu")
                , span [ TopAppBar.title ]
                    [ Icon.icon [] "rss_feed"
                    , span [] [ text " RSS Aggregator" ]
                    ]
                ]
            ]
        ]


drawerFrameRoot : List (Html.Attribute msg)
drawerFrameRoot =
    [ style "display" "-ms-flexbox"
    , style "display" "flex"
    , style "height" "100vh"
    ]


currentView : Model -> Html Msg
currentView model =
    case model.page of
        NotFoundPage ->
            notFoundView

        LoginPage pageModel ->
            Lazy.lazy LoginPage.view pageModel
                |> Html.map LoginPageMsg

        FeedsPage pageModel ->
            Lazy.lazy FeedsPage.view pageModel
                |> Html.map FeedsPageMsg

        PostsPage pageModel ->
            Lazy.lazy PostsPage.view pageModel
                |> Html.map PostsPageMsg

        NewFeedPage pageModel ->
            Lazy.lazy NewFeedPage.view pageModel
                |> Html.map NewFeedPageMsg


notFoundView : Html Msg
notFoundView =
    text "Page Not Found"



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
