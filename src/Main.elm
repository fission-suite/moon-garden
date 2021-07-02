module Main exposing (main)

import Browser
import Browser.Navigation as Navigation
import Dict exposing (Dict)
import Html.Styled as Html exposing (Html)
import Json.Decode as D exposing (Decoder)
import List.Extra as List
import Ports
import Random
import Return exposing (Return)
import Routes exposing (Route)
import Tailwind.Utilities exposing (..)
import Url exposing (Url)
import View



-- 🔠 ---------------------------------------------------------------------------


type alias Model =
    { url : Url
    , navKey : Navigation.Key
    , state : State
    }


type State
    = Unauthed Unauthenticated
    | Authed Authenticated -- FIXME add more actions to Authenticated


type Unauthenticated
    = Loading LoadingMessage
    | Cancelled
    | PleaseSignIn


type alias Authenticated =
    { notes : Dict String WNFSEntry
    , state : AuthenticatedState
    }


type AuthenticatedState
    = EditNote EditNoteState


type alias EditNoteState =
    { titleBuffer : String
    , editorBuffer : String
    , persistState : PersistState
    }


type PersistState
    = PersistedAs String
    | NotPersistedYet
    | LoadingNote


type Msg
    = NoOp -- FIXME Replace the need for this
    | UrlChanged Url
    | UrlRequested Browser.UrlRequest
    | WebnativeSignIn
    | WebnativeInit Bool
    | UpdateTitleBuffer String
    | UpdateEditorBuffer String
    | LoadedNote { noteName : String, noteData : String }
    | PersistedNote { noteName : String, noteData : String }
    | LoadedNotes (Result String (Dict String WNFSEntry))
    | CreateNewNote


type LoadingMessage
    = LoadingMessage String


type alias Flags =
    { randomness : Int
    }



-- 〽️  --------------------------------------------------------------------------


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        , onUrlChange = UrlChanged
        , onUrlRequest = UrlRequested
        }


init : Flags -> Url -> Navigation.Key -> Return Msg Model
init flags url navKey =
    let
        loadingMessage =
            Random.initialSeed flags.randomness
                |> Random.step randomLoadingMessage
                |> Tuple.first
    in
    { url = url
    , navKey = navKey
    , state = Unauthed (Loading (LoadingMessage loadingMessage))
    }
        |> Return.singleton



-- 🔁 --------------------------------------------------------------------------


update : Msg -> Model -> Return Msg Model
update msg model =
    case msg of
        NoOp ->
            model
                |> Return.singleton

        UrlChanged url ->
            { model | url = url }
                |> handleUrlChange

        UrlRequested request ->
            case request of
                Browser.External link ->
                    ( model
                    , Navigation.load link
                    )

                Browser.Internal url ->
                    ( { model | url = url }
                    , Navigation.pushUrl model.navKey (Url.toString url)
                    )

        WebnativeInit isAuthed ->
            if isAuthed then
                { model
                    | state =
                        Authed
                            { notes = Dict.empty
                            , state =
                                EditNote
                                    { titleBuffer = ""
                                    , editorBuffer = ""
                                    , persistState = NotPersistedYet
                                    }
                            }
                }
                    |> handleUrlChange

            else
                { model | state = Unauthed PleaseSignIn }
                    |> Return.singleton

        WebnativeSignIn ->
            ( model
            , Ports.redirectToLobby ()
            )

        UpdateTitleBuffer updatedTitle ->
            updateAuthed
                (\authed ->
                    updateEditNote
                        (\note ->
                            { note
                                | titleBuffer = updatedTitle
                            }
                                |> Return.singleton
                                |> returnEditNote authed
                                |> returnAuthed model
                        )
                        authed
                )
                model

        UpdateEditorBuffer updatedText ->
            updateAuthed
                (\authed ->
                    updateEditNote
                        (\note ->
                            { note
                                | editorBuffer = updatedText
                                , persistState = NotPersistedYet
                            }
                                |> Return.singleton
                                |> Return.effect_
                                    (\{ titleBuffer, editorBuffer } ->
                                        Ports.persistNote
                                            { noteName = titleBuffer
                                            , noteData = editorBuffer
                                            }
                                    )
                                |> returnEditNote authed
                                |> returnAuthed model
                        )
                        authed
                )
                model

        LoadedNotes result ->
            updateAuthed
                (\authed ->
                    case result of
                        Ok notes ->
                            { authed | notes = notes }
                                |> Return.singleton
                                |> returnAuthed model

                        Err _ ->
                            model
                                |> Return.singleton
                )
                model

        LoadedNote { noteName, noteData } ->
            updateAuthed
                (\authed ->
                    { titleBuffer = noteName
                    , editorBuffer = noteData
                    , persistState = PersistedAs noteName
                    }
                        |> Return.singleton
                        |> returnEditNote authed
                        |> returnAuthed model
                )
                model

        PersistedNote { noteName, noteData } ->
            updateAuthed
                (\authed ->
                    updateEditNote
                        (\note ->
                            if note.titleBuffer == noteName && note.editorBuffer == noteData then
                                { note | persistState = PersistedAs noteName }
                                    |> Return.singleton
                                    |> returnEditNote authed
                                    |> returnAuthed model

                            else
                                model
                                    |> Return.singleton
                        )
                        authed
                )
                model

        CreateNewNote ->
            updateAuthed
                (\authed ->
                    Return.return
                        { titleBuffer = ""
                        , editorBuffer = ""
                        , persistState = NotPersistedYet
                        }
                        -- TODO Change this to route to Routes.EditNote "" once the dashboard is implemeted
                        (Navigation.pushUrl model.navKey
                            (Routes.toLink Routes.Dashboard)
                        )
                        |> returnEditNote authed
                        |> returnAuthed model
                )
                model


updateAuthed : (Authenticated -> Return Msg Model) -> Model -> Return Msg Model
updateAuthed updater model =
    case model.state of
        Authed authed ->
            updater authed

        _ ->
            Return.singleton model


returnAuthed : Model -> Return Msg Authenticated -> Return Msg Model
returnAuthed model =
    Return.map (\authed -> { model | state = Authed authed })


updateEditNote : (EditNoteState -> Return Msg Model) -> Authenticated -> Return Msg Model
updateEditNote updater authed =
    case authed.state of
        EditNote editNoteState ->
            let
                ( newModel, cmds ) =
                    updater editNoteState
            in
            ( newModel
            , cmds
            )


returnEditNote : Authenticated -> Return Msg EditNoteState -> Return Msg Authenticated
returnEditNote authenticated =
    Return.map (\editNoteState -> { authenticated | state = EditNote editNoteState })


handleUrlChange : Model -> Return Msg Model
handleUrlChange model =
    case Routes.parse model.url of
        Just (Routes.EditNote name) ->
            updateAuthed
                (\authed ->
                    Return.return
                        { authed
                            | state =
                                EditNote
                                    { titleBuffer = name
                                    , editorBuffer = ""
                                    , persistState = LoadingNote
                                    }
                        }
                        (Ports.loadNote name)
                        |> returnAuthed model
                )
                model

        _ ->
            -- TODO: Implement a dashboard, go back to that
            ( model
            , Cmd.none
            )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Ports.webnativeInit WebnativeInit
        , Ports.loadedNotesLs (withDecoding (D.dict decodeWNFSEntry) LoadedNotes)
        , Ports.loadedNote LoadedNote
        , Ports.persistedNote PersistedNote
        ]


randomLoadingMessage : Random.Generator String
randomLoadingMessage =
    -- Source: https://gist.github.com/meain/6440b706a97d2dd71574769517e7ed32
    [ "Reticulating splines..."
    , "Generating witty dialog..."
    , "Swapping time and space..."
    , "Spinning violently around the y-axis..."
    , "Tokenizing real life..."
    , "Bending the spoon..."
    , "Filtering morale..."
    , "Don't think of purple hippos..."
    , "Checking the gravitational constant in your locale..."
    , "You're not in Kansas any more..."
    , "...at least you're not on hold..."
    , "Follow the white rabbit..."
    , "Counting backwards from Infinity..."
    ]
        |> Random.uniform "Loading..."



-- 🖼️  ---------------------------------------------------------------------------


view : Model -> Browser.Document Msg
view model =
    { title = "🌛 Moon Garden 🌱"
    , body = [ Html.toUnstyled <| viewBody model ]
    }


viewBody : Model -> Html Msg
viewBody model =
    case model.state of
        Unauthed unauthedState ->
            viewUnauthenticated unauthedState

        Authed authState ->
            viewAuthenticated authState


viewAuthenticated : Authenticated -> Html Msg
viewAuthenticated model =
    case model.state of
        EditNote note ->
            View.appShellSidebar
                { navigation =
                    [ View.leafyButton
                        { label = "Create New Note"
                        , onClick = CreateNewNote
                        }
                    , View.searchInput
                        { styles = [ mt_8 ]
                        , placeholder = "Type to Search"
                        , onInput = \_ -> NoOp
                        }
                    , model.notes
                        |> Dict.values
                        |> List.filterMap isMarkdownNote
                        |> List.sortBy (.modificationTime >> (*) -1)
                        |> List.map viewRecentNote
                        |> View.searchResults
                    ]
                , main =
                    [ View.titleInput
                        { onInput = UpdateTitleBuffer
                        , value = note.titleBuffer
                        , styles = []
                        }
                    , View.autoresizeTextarea
                        { onChange = UpdateEditorBuffer
                        , content = note.editorBuffer
                        , styles = [ View.editorTextareaStyle ]
                        }

                    -- , View.wikilinksSection
                    --     { styles = [ mt_8 ]
                    --     , wikilinks =
                    --         [ View.wikilinkExisting { label = "WNFS", link = "#" }
                    --         , View.wikilinkExisting { label = "Fission", link = "#" }
                    --         , View.wikilinkNew { label = "Markdown", onClickCreate = NoOp }
                    --         ]
                    --     }
                    ]
                }


viewUnauthenticated : Unauthenticated -> Html Msg
viewUnauthenticated model =
    case model of
        Loading (LoadingMessage message) ->
            View.loadingScreen { message = message, isError = False }

        Cancelled ->
            View.loadingScreen { message = "Auth cancelled", isError = True }

        PleaseSignIn ->
            View.signinScreen { onClickSignIn = WebnativeSignIn }


viewRecentNote : MarkdownNoteRef -> Html Msg
viewRecentNote note =
    View.referencedNoteCard
        { label = note.name
        , link = Routes.toLink (Routes.EditNote note.name)
        , styles = []
        }



-- Utilitites


withDecoding : Decoder a -> (Result String a -> msg) -> D.Value -> msg
withDecoding decoder toMsg json =
    D.decodeValue decoder json
        |> Result.mapError D.errorToString
        |> toMsg


type alias WNFSEntry =
    { isFile : Bool
    , name : String
    , cid : String
    , metadata :
        { unixMeta :
            { mtime : Int
            , ctime : Int
            }
        }
    }


decodeWNFSEntry : Decoder WNFSEntry
decodeWNFSEntry =
    D.map4 WNFSEntry
        (D.field "isFile" D.bool)
        (D.field "name" D.string)
        (D.field "cid" D.string)
        (D.field "metadata" decodeMetadata)


decodeMetadata : Decoder { unixMeta : { mtime : Int, ctime : Int } }
decodeMetadata =
    D.map2
        (\mtime ctime ->
            { unixMeta =
                { mtime = mtime
                , ctime = ctime
                }
            }
        )
        (D.at [ "unixMeta", "mtime" ] D.int)
        (D.at [ "unixMeta", "ctime" ] D.int)



-- MarkdownNote


type alias MarkdownNoteRef =
    { name : String
    , modificationTime : Int
    , creationTime : Int
    }


isMarkdownNote : WNFSEntry -> Maybe MarkdownNoteRef
isMarkdownNote entry =
    let
        ensureIsMarkdown ( name, extension ) =
            -- we require lowercase "md", because we will always save as .md
            if extension == "md" then
                Just name

            else
                Nothing
    in
    if entry.isFile then
        entry.name
            |> splitLast "."
            |> Maybe.andThen ensureIsMarkdown
            |> Maybe.map
                (\name ->
                    { name = name
                    , modificationTime = entry.metadata.unixMeta.mtime
                    , creationTime = entry.metadata.unixMeta.ctime
                    }
                )

    else
        Nothing


splitLast : String -> String -> Maybe ( String, String )
splitLast needle haystack =
    haystack
        |> String.split needle
        |> List.unconsLast
        |> Maybe.map
            (\( last, rest ) ->
                ( rest |> String.join needle
                , last
                )
            )
