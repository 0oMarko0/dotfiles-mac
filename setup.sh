#!/usr/bin/env bash

usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

This script installs or uninstalls brew packages and stows dotfiles for configuration.

Options:
  -h, --help         Show this help message and exit.
  --install FILE1 FILE2
                     Install brew and cask applications listed in FILE1 (brew.txt) and FILE2 (cask.txt).
  --uninstall FILE1 FILE2
                     Uninstall brew and cask applications listed in FILE1 (brew.txt) and FILE2 (cask.txt).
  --stow             Stow dotfiles to create symlinks for configuration files and folders.

Examples:
  Install brew and cask apps:
    $(basename "$0") --install brew.txt cask.txt

  Uninstall brew and cask apps:
    $(basename "$0") --uninstall brew.txt cask.txt

  Stow dotfiles:
    $(basename "$0") --stow

EOF
}

install_apps() {
  BREW_FILE=$1
  CASK_FILE=$2

  echo "Installing brew applications from $BREW_FILE"
  while read -r line; do 
    if [[ -n "$line" && "$line" != \#* ]]; then
      if brew list --formula "$line" &>/dev/null; then
        echo "Skipping $line, already installed."
      else
        echo "Installing $line..."
        brew install "$line"
      fi
    fi
  done < "$BREW_FILE"

  if [ ! -z "$CASK_FILE" ]; then
    echo "Installing cask applications from $CASK_FILE"
    while read -r line; do
      if [[ -n "$line" && "$line" != \#* ]]; then
        if brew list --cask "$line" &>/dev/null; then
          echo "Skipping cask $line, already installed."
        else
          echo "Installing cask $line..."
          brew install --cask "$line"
        fi
      fi
    done < "$CASK_FILE"
  fi
}

uninstall_apps() {
  BREW_FILE=$1
  CASK_FILE=$2

  echo "Uninstalling brew applications from $BREW_FILE"
  while read -r line; do 
    if [[ -n "$line" && "$line" != \#* ]]; then
      if ! brew list --formula "$line" &>/dev/null; then
        echo "Skipping $line, not installed."
      else
        echo "Uninstalling $line..."
        brew uninstall "$line"
      fi
    fi
  done < "$BREW_FILE"

  if [ ! -z "$CASK_FILE" ]; then
    echo "Uninstalling cask applications from $CASK_FILE"
    while read -r line; do
      if [[ -n "$line" && "$line" != \#* ]]; then
        if ! brew list --cask "$line" &>/dev/null; then
          echo "Skipping cask $line, not installed."
        else
          echo "Uninstalling cask $line..."
          brew uninstall --cask "$line"
        fi
      fi
    done < "$CASK_FILE"
  fi
}

# we want to use stow only for files, since a folder like .config will
# always contain many other files/folders, we don't want to symlink this folder
# that's what the --no-folding does
stow_dotfiles() {
  local files=(
    ".zshrc"
    ".vimrc"
  )
  local folders=(
    ".config/alacritty"
  )

  echo "Removing existing config files"
  for f in "${files[@]}"; do
    echo "-- $HOME/$f"
    rm -f "$HOME/$f" || true
  done 
  echo "Removing existing config folder"
  for d in "${folders[@]}"; do
    echo "-- $HOME/$d"
    rm -rf "$HOME/$d" || true
    mkdir -p "$HOME/$d"
  done
  local dotfiles=("alacritty" "zsh")
  for dotfile in "${dotfiles[@]}"; do
    stow --verbose 1 --no-folding "$dotfile"
  done
}

no_args=true
optspec=":h-:"
while getopts "$optspec" optchar; do
  no_args=false
  case "${optchar}" in
    #Short option
    h) usage; exit 0;;
    -)
      case "${OPTARG}" in
        # Long options
        help) usage; exit 0;;
        install) 
          # Expect two arguments after --install
          files=("${@:OPTIND:2}")         
           echo "FILE ${files[0]} ${files[1]}"
          if [[ ${#files[@]} -ne 2 ]]; then
            echo "Error: --install requires two file arguments. brew.txt and cask.txt"
            usage >&2
            exit 1
          fi
          install_apps "${files[0]}" "${files[1]}"
          OPTIND=$((OPTIND + 2)) # Skip the two arguments
          ;;
        uninstall) 
          # Expect two arguments after --install
          files=("${@:OPTIND:2}")
          if [[ ${#files[@]} -ne 2 ]]; then
            echo "Error: --uninstall requires two file arguments. brew.txt and cask.txt"
            usage >&2
            exit 1
          fi
          uninstall_apps "${files[0]}" "${files[1]}"
          OPTIND=$((OPTIND + 2)) # Skip the two arguments
          ;;
        stow) stow_dotfiles;;
        *)
          echo "Unknown option --${OPTARG}" >&2
          usage >&2;
          exit 1
          ;;
      esac;;
      *)
        echo "Unknown option -${OPTARG}" >&2
        usage >&2
        exit 1
        ;;
  esac
done

# Check if no arguments were passed
if $no_args; then
  usage
  exit 1
fi