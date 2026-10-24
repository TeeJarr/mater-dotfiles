#!/bin/bash
# Set up a new Mac from these dotfiles. Run it from the transfer kit folder:
#
#   bash bootstrap.sh [repo]     repo defaults to dotfiles.bundle next to this script,
#                                else the GitHub URL
#
# Anything else in the kit is used when present:
#   nvim.bundle        the nvim submodule, so it needs no GitHub sign-in
#   private/           untracked dotfiles (~/.gitconfig-work, ~/.gitconfig.local), copied to ~
#   zen-profile.zip    the Zen browser profile, put in place if Zen hasn't been restored yet
#
# Files in ~ that the checkout would overwrite are moved to ~/.dotfiles-backup first.
set -euo pipefail

KIT="$(cd "$(dirname "$0")" && pwd)"
GITHUB="https://github.com/TeeJarr/mater-dotfiles.git"
NVIM_GITHUB="https://github.com/TeeJarr/nvim.git"
REPO="${1:-}"
if [ -z "$REPO" ]; then
  if [ -f "$KIT/dotfiles.bundle" ]; then REPO="$KIT/dotfiles.bundle"; else REPO="$GITHUB"; fi
fi
BRANCH="personal-mac"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
ZEN_DIR="$HOME/Library/Application Support/zen"

step() { printf '\n==> %s\n' "$1"; }

step "Xcode command line tools"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install || true
  echo "Finish the install in the window that opened; this continues on its own."
  until xcode-select -p >/dev/null 2>&1; do sleep 5; done
fi

# A bundle path given relative to where the script was started
[ -f "$REPO" ] && REPO="$(cd "$(dirname "$REPO")" && pwd)/$(basename "$REPO")"

step "Dotfiles into ~ (branch $BRANCH)"
cd "$HOME"
if [ "$(git symbolic-ref --short -q HEAD 2>/dev/null)" = "$BRANCH" ] && git rev-parse -q --verify HEAD >/dev/null; then
  echo "Already checked out; skipping"
else
  # Also picks up a run that stopped partway through
  [ -d .git ] || git init -q
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "$GITHUB"
  git fetch -q "$REPO" "+$BRANCH:$BRANCH"
  # Back up anything the checkout would replace
  git ls-tree -r --name-only "$BRANCH" | while read -r f; do
    if [ -e "$f" ]; then mkdir -p "$BACKUP/$(dirname "$f")"; mv "$f" "$BACKUP/$f"; fi
  done
  git checkout -q "$BRANCH"
  git config status.showUntrackedFiles no
  [ -d "$BACKUP" ] && echo "Moved replaced files to $BACKUP"
fi

if [ -f "$KIT/nvim.bundle" ]; then
  # Clone the submodule from the kit, then point it back at GitHub
  git submodule init -q
  git config submodule..config/nvim.url "$KIT/nvim.bundle"
  git -c protocol.file.allow=always submodule update --recursive || echo "nvim submodule failed"
  git config submodule..config/nvim.url "$NVIM_GITHUB"
  if [ -e .config/nvim/.git ]; then git -C .config/nvim remote set-url origin "$NVIM_GITHUB"; fi
else
  git submodule update --init --recursive || echo "nvim submodule failed; rerun 'git submodule update --init' after 'gh auth login'"
fi

if [ -d "$KIT/private" ]; then
  step "Private dotfiles"
  for f in "$KIT"/private/.[!.]* "$KIT"/private/*; do
    [ -e "$f" ] || continue
    name="$(basename "$f")"
    if [ -e "$HOME/$name" ]; then echo "~/$name already exists; left as is"; else cp -R "$f" "$HOME/$name" && echo "Copied ~/$name"; fi
  done
fi

# Configs that hard-code the old home directory. The trailing slash keeps
# /Users/tristan from matching inside /Users/tristanreynolds.
for old in /Users/tristanreynolds /Users/tristan; do
  [ "$old" = "$HOME" ] && continue
  grep -rlI "$old/" .config .tmux.conf .zshrc 2>/dev/null | while read -r f; do
    sed -i '' "s|$old/|$HOME/|g" "$f"
  done
done

step "Homebrew"
if ! command -v brew >/dev/null && [ ! -x /opt/homebrew/bin/brew ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"
brew bundle --file="$HOME/Brewfile" || echo "Some Brewfile entries failed; see above and rerun 'brew bundle'"

step "tmux plugins"
[ -d "$HOME/.tmux/plugins/tpm" ] || git clone -q https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
"$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null || echo "tmux plugin install failed; press prefix + I inside tmux"

if [ -f "$KIT/zen-profile.zip" ]; then
  step "Zen profile"
  if pgrep -xq zen; then
    echo "Zen is running; quit it and rerun this script to restore the profile"
  elif [ -f "$ZEN_DIR/.restored-from-kit" ]; then
    echo "Already restored; skipping"
  else
    [ -d "$ZEN_DIR" ] && mv "$ZEN_DIR" "$ZEN_DIR.before-kit-$(date +%Y%m%d-%H%M%S)"
    ditto -x -k "$KIT/zen-profile.zip" "$HOME/Library/Application Support/"
    touch "$ZEN_DIR/.restored-from-kit"
    echo "Restored; open Zen to pick up where you left off"
  fi
fi

step "Services"
brew services start sketchybar >/dev/null 2>&1 || true
brew services start borders >/dev/null 2>&1 || true
brew services start rift >/dev/null 2>&1 || true

cat <<'EOF'

Done. Still to do by hand:
  - gh auth login                      (GitHub sign-in; also used by git)
  - gh auth login again as tristan-centability (work repos under github.com/Centability)
  - SSH key: ssh-keygen -t ed25519, then gh ssh-key add ~/.ssh/id_ed25519.pub
  - Grant Accessibility to Rift, Karabiner, Raycast and BetterDisplay in System Settings
  - Raycast: import the .rayconfig exported from the old Mac
  - Rift: arrange workspaces on your monitors, then Alt+Shift+S to save the layout
  - Open a new terminal so the shell config loads
EOF
