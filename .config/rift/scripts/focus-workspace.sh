#!/bin/bash
# i3 / AeroSpace-style workspaces across monitors.
#
#   focus-workspace.sh <index>          go to workspace <index> (0-based)
#   focus-workspace.sh --move <index>   send the focused window there, staying put
#
# Rift keeps a separate set of workspaces on every display. This treats each workspace
# number as living on one monitor: the monitor showing it, otherwise the monitor where it
# has windows, otherwise the focused monitor. Going to a workspace focuses its monitor
# instead of switching the monitor you're on.

PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"

move=false
if [ "$1" = "--move" ]; then
  move=true
  shift
fi
target="$1"
[ -n "$target" ] || exit 1

displays=$(rift-cli query displays) || exit 1
focused=$(jq -r '.[] | select(.is_active_context) | .uuid' <<<"$displays")

# "<uuid> <active index> <window count in target>" per display
state=$(
  for uuid in $(jq -r '.[].uuid' <<<"$displays"); do
    rift-cli query workspaces --display "$uuid" \
      | jq -r --arg uuid "$uuid" --argjson t "$target" \
          '"\($uuid) \(.[] | select(.is_active) | .index) \(.[] | select(.index == $t) | .window_count)"'
  done
)

owner=$(awk -v t="$target" '$2 == t { print $1; exit }' <<<"$state")
visible=true
if [ -z "$owner" ]; then
  visible=false
  # Prefer the focused monitor if it holds windows there, then any other monitor
  owner=$(awk -v f="$focused" '$1 == f && $3 > 0 { print $1; exit }' <<<"$state")
  [ -n "$owner" ] || owner=$(awk '$3 > 0 { print $1; exit }' <<<"$state")
  [ -n "$owner" ] || owner="$focused"
fi

if $move; then
  if [ "$owner" != "$focused" ] && $visible; then
    # Shown on another monitor: put the window there, keep focus here
    rift-cli execute display move-window --uuid "$owner" >/dev/null
    rift-cli execute display focus --uuid "$focused" >/dev/null
  else
    rift-cli execute workspace move-window "$target" >/dev/null
  fi
  exit 0
fi

[ "$owner" != "$focused" ] && rift-cli execute display focus --uuid "$owner" >/dev/null
$visible || rift-cli execute workspace switch "$target" >/dev/null
