#!/bin/bash
# One workspace "1", one "2", ... across all monitors, like AeroSpace and i3.
#
# Rift keeps a separate set of workspaces on every display, so after a restart every monitor
# shows its own empty "1". This runs on start and on every workspace_changed event: a monitor
# showing an empty workspace whose number is in use on another monitor (it has windows there,
# or is shown there) moves to the lowest number in use nowhere. If you switched to that number
# yourself, the monitor holding its windows shows them instead.

PATH="/opt/homebrew/bin:/usr/bin:/bin:$PATH"

# Our own switches fire workspace_changed again; one run at a time
lock="${TMPDIR:-/tmp}/rift-unique-workspaces.lock"
if ! mkdir "$lock" 2>/dev/null; then
	[ -n "$(find "$lock" -maxdepth 0 -mtime -10s 2>/dev/null)" ] && exit 0
	rm -rf "$lock"; mkdir "$lock" 2>/dev/null || exit 0
fi
trap 'rm -rf "$lock"' EXIT

displays=$(rift-cli query displays) || exit 1
focused=$(jq -r '.[] | select(.is_active_context) | .uuid' <<<"$displays")
count=$(rift-cli query workspaces | jq length)

# "<uuid> <active index> <windows in active> <comma-separated indices with windows>" per display,
# the focused display last so it keeps a number it just switched to whenever it can
state=$(
	for uuid in $(jq -r --arg f "$focused" '[.[] | select(.uuid != $f)] + [.[] | select(.uuid == $f)] | .[].uuid' <<<"$displays"); do
		rift-cli query workspaces --display "$uuid" | jq -r --arg u "$uuid" \
			'"\($u) \(.[] | select(.is_active) | .index) \(.[] | select(.is_active) | .window_count) \([.[] | select(.window_count > 0) | .index] | join(","))"'
	done
)

# Numbers in use: any workspace with windows, on any monitor, and every monitor's shown one
used=" $(awk '{ print $2; n = split($4, a, ","); for (i = 1; i <= n; i++) print a[i] }' <<<"$state" | sort -un | tr '\n' ' ')"

free_number() {
	local i
	for ((i = 0; i < count; i++)); do
		[[ "$used" == *" $i "* ]] || { echo "$i"; return; }
	done
}

# Owner of a number = a monitor with windows in it, else the first monitor showing it
owner_of() {
	awk -v i="$1" -v me="$2" '$1 != me { n = split($4, a, ","); for (k = 1; k <= n; k++) if (a[k] == i) { print $1; exit } }' <<<"$state"
}

claimed=" "
changed=false
while read -r uuid active windows _; do
	[ -n "$uuid" ] || continue
	if [ "$windows" -gt 0 ] || { [ -z "$(owner_of "$active" "$uuid")" ] && [[ "$claimed" != *" $active "* ]]; }; then
		claimed+="$active "
		continue
	fi

	# A duplicate: this monitor shows an empty copy of a number in use elsewhere
	owner=$(owner_of "$active" "$uuid")
	if [ "$uuid" = "$focused" ] && [ -n "$owner" ]; then
		# You went to it here, but its windows are on another monitor: show them there
		rift-cli execute display focus --uuid "$owner" >/dev/null
		rift-cli execute workspace switch "$active" >/dev/null
		claimed+="$active "
	fi
	target=$(free_number)
	[ -n "$target" ] || continue
	used+="$target "
	rift-cli execute display focus --uuid "$uuid" >/dev/null
	rift-cli execute workspace switch "$target" >/dev/null
	claimed+="$target "
	changed=true
	[ "$uuid" = "$focused" ] && [ -n "$owner" ] && focused="$owner"
done <<<"$state"

$changed && rift-cli execute display focus --uuid "$focused" >/dev/null
exit 0
