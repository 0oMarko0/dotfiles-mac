#!/usr/bin/env bash

# Assigns the first and second command-line arguments to GIT_USERNAME and GIT_EMAIL variables
GIT_USERNAME=$1
GIT_EMAIL=$2

# Sets the file path for the SSH key based on the GitHub username
SSH_FILE_PATH="$HOME/.ssh/gh_$GIT_USERNAME"

# Configures the SSH settings to use the generated key
SSH_CONFIG="
Host github.com
  UseKeychain yes
  AddKeysToAgent yes
  IdentityFile $SSH_FILE_PATH
"

function setupGit() {
  echo "Setup git configuration"
  git config --global user.name "$GIT_USERNAME"
  git config --global user.email "$GIT_EMAIL"
  # Enables GPG signing for commits
  git config --global commit.gpgsign true
}

function setupSSH() {
  echo "Setup SSH Config"
  echo "Do you want to set a passphrase for the SSH key? (y/n)"
  read -r SSH_PASSPHRASE
  if [ "$SSH_PASSPHRASE" = "y" ]; then
    echo "Enter passphrase: "
    read -r -s SSH_PASSPHRASE
  fi

  # Generates an SSH key with the given email as a label, using passphrase if set
  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_FILE_PATH" -N "$SSH_PASSPHRASE"
  # Adds the SSH key to the macOS keychain
  ssh-add --apple-use-keychain "$SSH_FILE_PATH"
  eval "$(ssh-agent -s)"

  if [[ ! -f "$HOME/.ssh/config" ]]; then
      touch "$HOME/.ssh/config"
  fi

  echo "$SSH_CONFIG" >> "$HOME/.ssh/config"

  if ! gh auth status > /dev/null 2>&1; then
    echo "Logging into GitHub using gh"
    gh auth login -h github.com -p ssh -w
  else
    echo "Already authenticated with GitHub."
    # Adds the public SSH key to GitHub via GitHub CLI
    gh ssh-key add -t "gh_$GIT_USERNAME" < "$SSH_FILE_PATH.pub"
  fi
}

function setupGPG() {
  # Checks if the GitHub token has write permissions for GPG keys
  scopes=$(curl -s -I -H "Authorization: token $(gh auth token)" https://api.github.com/user | grep 'X-OAuth-Scopes:')
  if echo "$scopes" | grep -q "write:gpg_key"; then
    echo "Token has the write:gpg_key permission."
  else
    echo "Token does NOT have the write:gpg_key permission."
    gh auth refresh -s write:gpg_key
  fi

  echo "Setup GPG key for commit signature"
  echo "Do you want to set a passphrase for the GPG key? (y/n)"
  read -r GPG_PASSPHRASE
  if [ "$GPG_PASSPHRASE" = "y" ]; then
    echo "Enter passphrase: "
    read -r -s GPG_PASSPHRASE
  fi

  # Generates a GPG key with the given username and email, using passphrase if set
  gpg --batch --generate-key <<EOF
  %no-protection
  Key-Type: default
  Key-Length: default
  Expire-Date: 0
  Name-Real: $GIT_USERNAME
  Name-Email: $GIT_EMAIL
  Passphrase: $GPG_PASSPHRASE
EOF

  # Retrieves the GPG key ID and uploads it to GitHub via GitHub CLI
  KEY_ID=$(gpg --list-secret-keys --keyid-format=long | awk '/sec/{print $2}' | tail -n1 | cut -d'/' -f2)
  gpg --armor --export "$KEY_ID" | gh gpg-key add -t "gpg_$GIT_USERNAME"
}

setupGit
setupSSH
setupGPG