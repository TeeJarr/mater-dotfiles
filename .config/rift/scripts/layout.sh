#!/bin/bash
# Saved layout for Rift: which monitor each workspace lives on, and the arrangement of
# windows inside every workspace.
#
#   layout.sh save      remember the current arrangement (Alt+Shift+S)
#   layout.sh restore   put every monitor's windows back into the saved arrangement (Alt+Shift+R)
#   layout.sh check     list windows that are on the wrong monitor, change nothing
#   layout.sh place     (run by Rift on windows_changed) move a newly opened window that lands
#                       in a workspace on the wrong monitor to the monitor that workspace lives on
#
# Which app opens in which workspace is set by app_rules in config.toml; Rift can't pick
# the monitor there, which is what `place` adds.

PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"

DIR="$HOME/.config/rift/layouts"
SNAPSHOT="$DIR/home.ron"
HOMES="$DIR/workspace-homes.tsv"   # "<workspace index>\t<display uuid>\t<display name>"

# `display move-window --uuid` does nothing in Rift 0.7.0 (it reports success); `--index` works,
# so look up the display's position in `rift-cli query displays`
display_index() { rift-cli query displays | jq -r --arg u "$1" 'map(.uuid) | index($u)'; }

focused_display() { rift-cli query displays | jq -r '.[] | select(.is_active_context) | .uuid'; }

save() {
  mkdir -p "$DIR"
  rift-cli execute save-layout "$SNAPSHOT" >/dev/null || exit 1
  # Every workspace with windows lives on the monitor it's on now
  rift-cli query displays | jq -r '.[] | "\(.uuid)\t\(.name)"' | while IFS=$'\t' read -r uuid name; do
    rift-cli query workspaces --display "$uuid" \
      | jq -r --arg uuid "$uuid" --arg name "$name" \
          '.[] | select(.window_count > 0) | "\(.index)\t\($uuid)\t\($name)"'
  done | sort -n > "$HOMES"
  osascript -e 'display notification "Saved the current layout" with title "Rift"'
}

restore() {
  [ -f "$SNAPSHOT" ] || { echo "layout.sh: nothing saved yet" >&2; exit 1; }
  local focused uuid
  focused=$(focused_display)
  # Windows first go home, then each monitor's Space reloads its saved workspaces
  place_all
  for uuid in $(rift-cli query displays | jq -r '.[].uuid'); do
    rift-cli execute display focus --uuid "$uuid" >/dev/null
    rift-cli execute load-layout "$SNAPSHOT" --scope space >/dev/null
  done
  rift-cli execute display focus --uuid "$focused" >/dev/null
}

# Move one window ("<pid> <idx>") into workspace <index> on display <uuid>
move_home() {
  local pid="$1" idx="$2" index="$3" home="$4"
  rift-cli execute display move-window --index "$(display_index "$home")" --window-id "$idx" >/dev/null
  local active
  active=$(rift-cli query workspaces --display "$home" | jq -r '.[] | select(.is_active) | .index')
  if [ "$active" != "$index" ]; then
    # It landed in the home monitor's visible workspace; send it on to its own
    rift-cli execute window focus --window-id "{\"pid\":$pid,\"idx\":$idx}" >/dev/null
    rift-cli execute workspace move-window "$index" >/dev/null
  fi
}

# Every window in a workspace that isn't on that workspace's home monitor
misplaced() {
  [ -f "$HOMES" ] || return
  local connected uuid
  connected=$(rift-cli query displays | jq -r '.[].uuid')
  for uuid in $connected; do
    rift-cli query workspaces --display "$uuid" | jq -r '.[] | select(.window_count > 0)
      | .index as $i | .windows[] | "\($i)\t\(.id.pid)\t\(.id.idx)"' \
      | while IFS=$'\t' read -r index pid idx; do
          home=$(awk -F'\t' -v i="$index" '$1 == i { print $2 }' "$HOMES")
          # Leave it if the workspace has no home or its monitor isn't plugged in
          [ -n "$home" ] && [ "$home" != "$uuid" ] && grep -qx "$home" <<<"$connected" \
            && printf '%s\t%s\t%s\t%s\n' "$pid" "$idx" "$index" "$home"
        done
  done
  return 0
}

# Windows seen by the last `place` run ("<pid>\t<idx>" per line)
KNOWN="${TMPDIR:-/tmp}/rift-layout-known-windows"

all_windows() {
  for uuid in $(rift-cli query displays | jq -r '.[].uuid'); do
    rift-cli query workspaces --display "$uuid" | jq -r '.[].windows[] | "\(.id.pid)\t\(.id.idx)"'
  done | sort -u
}

# $1 = "new": only windows that weren't there last time, so a window or workspace you move
# to another monitor on purpose isn't dragged back
place_all() {
  local moves focused
  moves=$(misplaced)
  if [ "$1" = "new" ]; then
    local now
    now=$(all_windows)
    [ -f "$KNOWN" ] && moves=$(awk -F'\t' 'NR == FNR { seen[$1 FS $2]; next } !(($1 FS $2) in seen)' "$KNOWN" - <<<"$moves")
    printf '%s\n' "$now" > "$KNOWN"
  fi
  [ -n "$moves" ] || return 0
  focused=$(focused_display)
  while IFS=$'\t' read -r pid idx index home; do
    move_home "$pid" "$idx" "$index" "$home"
  done <<<"$moves"
  rift-cli execute display focus --uuid "$focused" >/dev/null
}

place() {
  # Moving windows fires more windows_changed events; one run at a time, and a run that
  # finds the lock taken leaves it to the running one
  local lock="${TMPDIR:-/tmp}/rift-layout-place.lock"
  if ! mkdir "$lock" 2>/dev/null; then
    [ -n "$(find "$lock" -maxdepth 0 -mtime -10s 2>/dev/null)" ] && exit 0
    rm -rf "$lock"; mkdir "$lock" 2>/dev/null || exit 0
  fi
  trap 'rm -rf "$lock"' EXIT
  place_all new
}

case "$1" in
  save) save ;;
  restore) restore ;;
  place) place ;;
  check) misplaced ;;
  *) sed -n '2,13s/^# \{0,1\}//p' "$0"; exit 1 ;;
esac
