#!/usr/bin/env bash

usage() {
  echo "Usage: $0 [--install|--uninstall] <BREW_FILE> [CASK_FILE]"
  echo ""
  echo "Options:"
  echo "  --install    Install applications from BREW_FILE and optionally from CASK_FILE."
  echo "  --uninstall  Uninstall applications from BREW_FILE and optionally from CASK_FILE."
  echo ""
  echo "Arguments:"
  echo "  BREW_FILE    File containing a list of applications for Homebrew."
  echo "  CASK_FILE    (Optional) File containing a list of applications for Homebrew Cask."
  echo ""
  exit 1
}

if [ $# -lt 2 ]; then
  usage
fi

ACTION=$1
BREW_FILE=$2
CASK_FILE=$3

if [[ "$ACTION" != "--install" && "$ACTION" != "--uninstall" ]]; then
  usage
fi

if [ ! -f "$BREW_FILE" ]; then
  echo "Error: BREW_FILE '$BREW_FILE' does not exist."
  exit 1
fi

if [ ! -z "$CASK_FILE" ] && [ ! -f "$CASK_FILE" ]; then
  echo "Error: CASK_FILE '$CASK_FILE' does not exist."
  exit 1
fi

install_apps() {
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

if [ "$ACTION" == "--install" ]; then
  install_apps
elif [ "$ACTION" == "--uninstall" ]; then
  uninstall_apps
elif [ "$ACTION" == "--config" ]; then
  echo "config"
else
  usage
fi
