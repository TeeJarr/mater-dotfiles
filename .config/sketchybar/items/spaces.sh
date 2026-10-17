#!/bin/bash



sketchybar --add event aerospace_workspace_change

for sid in $(aerospace list-workspaces --monitor 1 --empty no); do
	sketchybar --add item space.$sid left \
						 --subscribe space.$sid aerospace_workspace_change \
						 --set space.$sid \
						 background.color=0xffebdbb2 \
             icon.font="sketchybar-app-font:Regular:14.0" \
						 background.corner_radius=5 \
						 background.height=20 \
						 background.drawing=off \
						 label="$sid"\
						 click_script="aerospace worskspace $sid" \
						 script="$CONFIG_DIR/plugins/space.sh $sid"
					 done

for sid in $(aerospace list-workspaces --monitor 1 --empty no); do
  apps=$(aerospace list-windows --workspace "$sid" | awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}')

  sketchybar --set space.$sid drawing=on

  icon_strip=" "
  if [ "${apps}" != "" ]; then
    while read -r app; do
      icon_strip+="$($CONFIG_DIR/plugins/icon_map_fn.sh "$app")"
    done <<<"${apps}"
  else
    icon_strip=""
  fi
  sketchybar --set space.$sid icon="$icon_strip"
done


