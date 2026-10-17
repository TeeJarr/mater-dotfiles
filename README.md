# dotfiles

The work tree is `$HOME` itself, so configs live where apps expect them. `.gitignore`
ignores everything except the files listed in it.

Branches: `personal-mac` (personal MacBook), `work-mac`, `linux-desktop`.

## New Mac

```sh
cd ~
bash bootstrap.sh ~/Downloads/dotfiles.bundle     # from the AirDropped bundle
# or
bash bootstrap.sh https://github.com/TeeJarr/mater-dotfiles.git
```

It installs the Xcode CLI tools and Homebrew, checks out `personal-mac` into `~` (backing
up any file it replaces), runs the `Brewfile`, installs Oh My Zsh and tpm, and starts Rift,
SketchyBar and borders.

## Day to day

```sh
git -C ~ status            # untracked files are hidden
git -C ~ add -f .config/<app>   # start tracking a new config (and add it to .gitignore)
brew bundle dump --force --file=~/Brewfile   # after installing new packages
```

Keep secrets and machine-only settings in `~/.zshrc.local` and `~/.gitconfig.local`; both
are sourced but never tracked.
