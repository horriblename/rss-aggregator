port module Main exposing (main, storeApiKey)

-- import Browser.Navigation as Nav

import Browser exposing (Document, UrlRequest)
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Material.Typography exposing (typography)
import Page.Login as LoginPage exposing (OutMsg(..))
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
    }


type Page
    = NotFoundPage
    | LoginPage LoginPage.Model
    | FeedsPage FeedsPage.Model
    | PostsPage PostsPage.Model


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

        -- case model.apiKey of
        --     Nothing ->
        --         ( NotFoundPage, Nav.pushUrl model.navKey "/login" )
        --
        --     Just apiKey ->
        --         let
        --             ( pageModel, pageCmds ) =
        --                 FeedsPage.init apiKey
        --         in
        --         ( FeedsPage pageModel, Cmd.map FeedsPage pageCmds )
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
    | LinkClicked UrlRequest
    | UrlChanged Url


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

        ( _, _ ) ->
            ( model, Cmd.none )


type SignalFromChild
    = LoginPageSignal (Maybe LoginPage.OutMsg)


processSignal : Model -> SignalFromChild -> ( Model, Cmd Msg )
processSignal model signal =
    case signal of
        LoginPageSignal (Just (LoggedIn { apiKey })) ->
            ( { model | apiKey = Just apiKey }, storeApiKey apiKey )

        _ ->
            ( model, Cmd.none )



-- VIEW


view : Model -> Document Msg
view model =
    { title = "RSS Aggregator"
    , body = [ Html.div [ typography ] [ currentView model ] ]
    }


currentView : Model -> Html Msg
currentView model =
    case model.page of
        NotFoundPage ->
            notFoundView

        LoginPage pageModel ->
            LoginPage.view pageModel
                |> Html.map LoginPageMsg

        FeedsPage pageModel ->
            FeedsPage.view pageModel
                |> Html.map FeedsPageMsg

        PostsPage pageModel ->
            PostsPage.view pageModel
                |> Html.map PostsPageMsg


notFoundView : Html Msg
notFoundView =
    text "Page Not Found"



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
