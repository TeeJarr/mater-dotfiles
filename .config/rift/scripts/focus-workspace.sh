#!/bin/bash
# i3 / AeroSpace-style workspaces across monitors.
#
#   focus-workspace.sh <index>          go to workspace <index> (0-based)
#   focus-workspace.sh --move <index>   send the focused window there and follow it
#
# Rift keeps a separate set of workspaces on every display. This treats each workspace
# number as living on one monitor: the monitor showing it, otherwise the monitor where it
# has windows, otherwise the focused monitor. Going to a workspace focuses its monitor
# instead of switching the monitor you're on.

PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"

# `display move-window --uuid` does nothing in Rift 0.7.0 (it reports success); `--index` works,
# so look up the display's position in `rift-cli query displays`
display_index() { rift-cli query displays | jq -r --arg u "$1" 'map(.uuid) | index($u)'; }

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
  window=$(rift-cli query windows | jq -c '.[] | select(.is_focused) | {pid: .id.pid, idx: .id.idx}')
  [ -n "$window" ] || exit 0
  if [ "$owner" != "$focused" ]; then
    # The workspace lives on another monitor: put the window there and follow it, so the
    # number never holds windows on two monitors
    rift-cli execute display move-window --index "$(display_index "$owner")" --window-id "$(jq -r .idx <<<"$window")" >/dev/null
    rift-cli execute display focus --uuid "$owner" >/dev/null
    if ! $visible; then
      # It landed in whatever that monitor shows; send it on to its workspace
      rift-cli execute window focus --window-id "$window" >/dev/null
      rift-cli execute workspace move-window "$target" >/dev/null
      rift-cli execute workspace switch "$target" >/dev/null
    fi
  else
    rift-cli execute workspace move-window "$target" >/dev/null
    rift-cli execute workspace switch "$target" >/dev/null
  fi
  # Workspaces remember their own focus, so focus the moved window explicitly
  rift-cli execute window focus --window-id "$window" >/dev/null
  exit 0
fi

[ "$owner" != "$focused" ] && rift-cli execute display focus --uuid "$owner" >/dev/null
$visible || rift-cli execute workspace switch "$target" >/dev/null
