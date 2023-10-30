module Common exposing (Resource(..), isFailed, isLoaded, isLoading)


type Resource err a
    = Loading
    | Failed err
    | Loaded a


isLoaded : Resource err a -> Bool
isLoaded res =
    case res of
        Loaded _ ->
            True

        _ ->
            False


isLoading : Resource err a -> Bool
isLoading res =
    case res of
        Loading ->
            True

        _ ->
            False


isFailed : Resource err a -> Bool
isFailed res =
    case res of
        Failed _ ->
            True

        _ ->
            False
