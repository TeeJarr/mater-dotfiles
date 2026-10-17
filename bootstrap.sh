#!/bin/bash
# Set up a new Mac from these dotfiles. Run from the home directory:
#
#   bash bootstrap.sh <repo>     <repo> is the dotfiles.bundle file or the GitHub URL
#
# Files in ~ that the checkout would overwrite are moved to ~/.dotfiles-backup first.
set -euo pipefail

REPO="${1:-https://github.com/TeeJarr/mater-dotfiles.git}"
BRANCH="personal-mac"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

step() { printf '\n==> %s\n' "$1"; }

step "Xcode command line tools"
xcode-select -p >/dev/null 2>&1 || { xcode-select --install; read -rp "Press Enter once the install finishes... "; }

step "Dotfiles into ~ (branch $BRANCH)"
cd "$HOME"
if [ -d .git ]; then
  echo "~/.git already exists; skipping the checkout"
else
  git init -q
  git remote add origin https://github.com/TeeJarr/mater-dotfiles.git
  git fetch -q "$REPO" "$BRANCH:$BRANCH"
  # Back up anything the checkout would replace
  git ls-tree -r --name-only "$BRANCH" | while read -r f; do
    if [ -e "$f" ]; then mkdir -p "$BACKUP/$(dirname "$f")"; mv "$f" "$BACKUP/$f"; fi
  done
  git checkout -q "$BRANCH"
  git config status.showUntrackedFiles no
  [ -d "$BACKUP" ] && echo "Moved replaced files to $BACKUP"
fi
git submodule update --init --recursive || echo "nvim submodule failed; rerun 'git submodule update --init' after 'gh auth login'"

# Configs that hard-code the old home directory
if [ "$HOME" != "/Users/tristan" ]; then
  grep -rlI "/Users/tristan" .config .tmux.conf 2>/dev/null | while read -r f; do
    sed -i '' "s|/Users/tristan|$HOME|g" "$f"
  done
fi

step "Homebrew"
if ! command -v brew >/dev/null && [ ! -x /opt/homebrew/bin/brew ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"
brew bundle --file="$HOME/Brewfile" || echo "Some Brewfile entries failed; see above and rerun 'brew bundle'"

step "Oh My Zsh and plugins"
[ -d "$HOME/.oh-my-zsh" ] || RUNZSH=no KEEP_ZSHRC=yes \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom/plugins"
[ -d "$ZSH_CUSTOM/zsh-autosuggestions" ] || git clone -q https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/zsh-autosuggestions"
[ -d "$ZSH_CUSTOM/zsh-syntax-highlighting" ] || git clone -q https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/zsh-syntax-highlighting"

step "tmux plugin manager"
[ -d "$HOME/.tmux/plugins/tpm" ] || git clone -q https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"

step "Services"
brew services start sketchybar >/dev/null 2>&1 || true
brew services start borders >/dev/null 2>&1 || true
rift service install >/dev/null 2>&1 && rift service start >/dev/null 2>&1 || true

cat <<'EOF'

Done. Still to do by hand:
  - gh auth login                      (GitHub sign-in; also used by git)
  - SSH key: ssh-keygen -t ed25519, then gh ssh-key add ~/.ssh/id_ed25519.pub
  - Grant Accessibility to Rift, Karabiner, Raycast and BetterDisplay in System Settings
  - Raycast: import the .rayconfig exported from the old Mac
  - Rift: arrange workspaces on your monitors, then Alt+Shift+S to save the layout
  - tmux: press prefix + I to install plugins
  - Open a new terminal so the shell config loads
EOF
