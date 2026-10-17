#!/bin/bash

sketchybar --add item front_app left \
            --set front_app       background.color=$ACCENT_COLOR \
																	background.drawing=off \
																 background.padding_right=7\
                                 icon.color=0xfff0f0f0 \
                                 icon.font="sketchybar-app-font:Regular:14.0" \
                                 label.color=$ITEM_BG_COLOR \
                                 script="$PLUGIN_DIR/front_app.sh"            \
           --subscribe front_app front_app_switched
