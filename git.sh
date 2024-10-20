#!/usr/bin/env bash

SSH_PASSPHRASE=""
GPG_PASSPHRASE=""
GIT_USER_NAME="mogagnon"
GIT_EMAIL="mogagnon1@gmail.com"
SSH_FILE_PATH="$HOME/.ssh/gh_$GIT_USER_NAME"
SSH_CONFIG="
Host github.com
  UseKeychain yes
  AddKeysToAgent yes
  IdentityFile $SSH_FILE_PATH
"

echo "Setup git configuration"
git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global commit.gpgsign true

echo "Setup SSH Config"
echo "Do you want to set a passphrase for the SSH key? (y/n)"
read -r SSH_PASSPHRASE
if [ "$SSH_PASSPHRASE" = "y" ]; then
  echo "Enter passphrase: "
  read -r -s SSH_PASSPHRASE
fi

ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_FILE_PATH" -N "$SSH_PASSPHRASE" && ssh-add --apple-use-keychain "$SSH_FILE_PATH"
eval "$(ssh-agent -s)"

if [[ ! -f "$HOME/.ssh/config" ]]; then
    touch "$HOME/.ssh/config"
fi

echo "$SSH_CONFIG" >> "$HOME/.ssh/config"
ssh-add --apple-use-keychain "$SSH_FILE_PATH"

if ! gh auth status > /dev/null 2>&1; then
  echo "Logging into GitHub using gh"
  gh auth login -h github.com -p ssh -w
else
  echo "Already authenticated with GitHub."
fi

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

gpg --batch --generate-key <<EOF
%no-protection
Key-Type: default
Key-Length: default
Expire-Date: 0
Name-Real: $GIT_USER_NAME
Name-Email: $GIT_EMAIL
Passphrase: $GPG_PASSPHRASE
EOF

gh auth refresh -s write:gpg_key
KEY_ID=$(gpg --list-secret-keys --keyid-format=long | awk '/sec/{print $2}' | tail -n1 | cut -d'/' -f2)
gpg --armor --export "$KEY_ID" | gh gpg-key add -t test