module Route exposing (Route(..), apiBaseUrl, parseUrl)

import Url exposing (Url)
import Url.Parser exposing (..)


type Route
    = NotFound
    | Posts
    | Login
    | Feeds
    | NewFeed


parseUrl : Url -> Route
parseUrl url =
    case parse matchRoute url of
        Just route ->
            route

        Nothing ->
            NotFound


apiBaseUrl : String
apiBaseUrl =
    "http://localhost:8080"


matchRoute : Parser (Route -> a) a
matchRoute =
    oneOf
        [ map Posts top
        , map Posts (s "posts")
        , map Login (s "login")
        , map Feeds (s "feeds")
        , map NewFeed (s "feeds" </> s "new")
        ]
