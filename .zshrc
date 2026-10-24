# Plain zsh, no framework: Starship draws the prompt, Homebrew supplies the plugins.

export LANG=en_US.UTF-8
export EDITOR='nvim'

# ---- PATH (first match wins; -U drops duplicates) ----
typeset -U path
path=(
	/opt/homebrew/opt/ruby/bin
	/opt/homebrew/opt/postgresql@16/bin
	"$HOME/Library/Application Support/pypoetry/venv/bin"
	$HOME/.local/bin
	$HOME/bin
	/opt/homebrew/bin
	$path
	$HOME/.bin
)

# ---- History ----
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt extended_history share_history hist_ignore_dups hist_ignore_space hist_verify

# ---- Directories ----
setopt auto_cd auto_pushd pushd_ignore_dups pushd_minus
alias -- -='cd -'
alias ..='cd ..'
alias ...='cd ../..'

# ---- Completion (the dump is rebuilt at most once a day) ----
fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
autoload -Uz compinit
() {
	setopt local_options extended_glob
	if [[ -n ~/.zcompdump(#qN.mh+24) || ! -f ~/.zcompdump ]]; then
		compinit
	else
		compinit -C
	fi
}
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
setopt complete_in_word always_to_end

# ---- Keys: emacs mode; Up/Down search history by what's already typed ----
bindkey -e
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

# ---- Aliases ----
alias c=clear
alias y=yazi
alias ls="eza --all --group-directories-last -h --icons --color=auto -G -l -h -B --no-permissions --no-user --no-time"
alias zen-debug='open -a "Zen" --args --start-debugger-server 9222'
alias g=git
alias gst='git status'
alias ga='git add'
alias gc='git commit'
alias gco='git checkout'
alias gsw='git switch'
alias gd='git diff'
alias gl='git pull'
alias gp='git push'
alias glog='git log --oneline --decorate --graph'

# ---- Tools ----
# Tokyo Night (night) colours for fzf, and lazygit's config kept with the other dotfiles
export FZF_DEFAULT_OPTS="--highlight-line --info=inline-right --layout=reverse --border=none \
  --color=bg+:#283457,bg:#16161e,border:#27a1b9,fg:#c0caf5,gutter:#16161e,header:#ff9e64 \
  --color=hl+:#2ac3de,hl:#2ac3de,info:#545c7e,marker:#ff007c,pointer:#ff007c,prompt:#2ac3de \
  --color=query:#c0caf5:regular,scrollbar:#27a1b9,separator:#ff9e64,spinner:#ff007c"
export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml"
eval "$(zoxide init zsh)"
# Ctrl+T files, Ctrl+R history, Alt+C cd into a directory
source <(fzf --zsh)
# Ctrl+F: pick a project and open it in its own tmux session (~/.local/bin/tmux-sessionizer)
bindkey -s '^f' 'tmux-sessionizer\n'

source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# ---- Starship prompt (Tokyo Night preset) ----
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
eval "$(starship init zsh)"

# Machine-only settings (work aliases, secrets) stay out of the repo
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# Syntax highlighting has to load last
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
export PATH="/opt/homebrew/lib/ruby/gems/4.0.0/bin:$PATH"
