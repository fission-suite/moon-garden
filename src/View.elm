module View exposing (..)

import Css
import FeatherIcons
import Html.Styled as Html exposing (..)
import Html.Styled.Attributes exposing (css, href, id, placeholder, type_)
import Html.Styled.Events as Events
import Tailwind.Breakpoints exposing (..)
import Tailwind.Utilities exposing (..)


test : msg -> Html msg
test noOp =
    -- signinScreen { onClickSignIn = noOp }
    -- loadingScreen { message = "Spinning violently around the y-axis..." }
    appShellSidebar


loadingScreen : { message : String } -> Html msg
loadingScreen element =
    appShellCentered
        [ moonGarden
        , p
            [ css
                [ font_body
                , text_bluegray_700
                , flex
                , flex_col
                , items_center
                , space_y_2
                ]
            ]
            [ span
                [ css
                    [ text_2xl
                    , animate_spin
                    ]
                ]
                [ text "🌕" ]
            , span [] [ text element.message ]
            ]
        ]


signinScreen : { onClickSignIn : msg } -> Html msg
signinScreen element =
    appShellCentered
        [ moonGarden
        , p
            [ css
                [ text_bluegray_800
                , text_center
                , font_body
                ]
            ]
            [ text "is a digital garden app built on the Fission Platform."
            , br [] []
            , br [] []
            , text "Start your own digital garden by logging in to your fission account or creating a new one:"
            ]
        , button
            [ Events.onClick element.onClickSignIn
            , css
                [ px_12
                , py_3
                , leafButtonStyle
                ]
            ]
            [ text "Sign in With Fission" ]
        ]


appShellCentered : List (Html msg) -> Html msg
appShellCentered content =
    div
        [ css
            [ bg_beige_100
            , items_center
            , flex
            , flex_col
            , flex_grow
            , flex_shrink_0
            ]
        ]
        [ main_
            [ css
                [ max_w_md
                , m_auto
                , flex
                , flex_col
                , items_center
                , space_y_8
                ]
            ]
            content
        ]


appShellSidebar : Html msg
appShellSidebar =
    div
        [ css
            [ bg_beige_100
            , flex
            , flex_row
            , flex_grow
            , flex_shrink_0
            , overflow_x_auto
            , Css.property "scroll-snap-type" "x mandatory"
            ]
        ]
        [ div
            [ css
                [ w_64
                , py_6
                , flex_shrink_0
                , Css.property "scroll-snap-align" "start"
                , overflow_y_auto
                , flex
                , flex_col
                ]
            ]
            [ div
                [ css
                    [ border_beige_300
                    , border_r_4
                    , px_5
                    , flex
                    , flex_col
                    , flex_grow
                    ]
                ]
                (List.concat
                    [ [ button
                            [ css
                                [ leafButtonStyle
                                , py_3
                                ]
                            ]
                            [ text "Create New Note" ]
                      , searchInput [ mt_8 ]
                      ]
                    , List.map
                        (\result ->
                            searchResult
                                { label = result
                                , link = "#dashboard"
                                , styles = [ mt_4 ]
                                }
                        )
                        [ "Moon Garden"
                        , "Markdown"
                        , "WNFS"
                        , "Wikilinks"
                        , "Geometric Algebra for Computer Science"
                        ]
                    ]
                )
            ]
        , div
            [ id "dashboard"
            , css
                [ p_6
                , Css.property "min-width" "100vw"
                , flex_grow
                , flex_shrink_0
                , h_full
                , Css.property "scroll-snap-align" "start"
                , overflow_y_auto
                ]
            ]
            [ moonGarden ]
        ]


moonGarden : Html msg
moonGarden =
    h1
        [ css
            [ text_bluegray_800
            , text_center
            , text_2xl
            , font_title
            , sm [ text_5xl ]
            ]
        ]
        [ text "Moon Garden" ]


searchInput : List Css.Style -> Html msg
searchInput styles =
    div
        [ css
            [ relative
            , flex
            , flex_col
            , Css.batch styles
            ]
        ]
        [ input
            [ type_ "text"
            , placeholder "Type to Search"
            , css
                [ px_4
                , py_3
                , rounded_md
                , bg_beige_200
                , focusable
                , font_mono
                , Css.pseudoElement "placeholder"
                    [ text_beige_400
                    ]
                ]
            ]
            []
        , FeatherIcons.search
            |> FeatherIcons.withSize 20
            |> FeatherIcons.toHtml []
            |> fromUnstyled
            |> List.singleton
            |> span
                [ css
                    [ text_beige_400
                    , my_auto
                    ]
                ]
            |> List.singleton
            |> div
                [ css
                    [ absolute
                    , pointer_events_none
                    , right_4
                    , inset_y_0
                    , flex
                    , flex_row
                    ]
                ]
        ]


searchResult :
    { label : String
    , link : String
    , styles : List Css.Style
    }
    -> Html msg
searchResult element =
    a
        [ href element.link
        , css
            [ Css.batch element.styles
            , rounded_md
            , bg_beige_200
            , px_4
            , py_3
            , focusable
            , font_body
            , text_bluegray_800
            , transform_gpu
            , transition_transform
            , Css.active
                [ scale_95 ]
            ]
        ]
        [ text element.label ]


leafButtonStyle : Css.Style
leafButtonStyle =
    Css.batch
        [ -- font
          font_button
        , Css.property "font-weight" "100"

        -- colors
        , bg_leaf_600
        , text_white
        , Css.property "box-shadow" "0 0.25rem 0 0 #95A25C"
        , focusable

        -- corners
        , rounded_md
        , rounded_tl_3xl
        , rounded_br_3xl

        -- button press animation
        , transform_gpu
        , translate_y_0
        , Css.property "transition-property" "transform box-shadow"
        , duration_100
        , Css.active
            [ translate_y_1
            , Css.property "box-shadow" "0 0 0 0 #95A25C"
            ]
        ]
