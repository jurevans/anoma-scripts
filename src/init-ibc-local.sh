#!/bin/bash -e

# init-ibc-local.sh
# Set up a local instance of ibc-rs (Hermes) with two IBC-enabled Namada chains

usage() {
  cat << EOF >&2

Usage: $0 [-h] [-s]

  -s: Use SSH for Github repos (defaults to https)
  -h: Show this message

EOF
  exit 1
}

check_dependencies() {
  if ! command -v git &> /dev/null
  then
    echo "git could not be found, but is a required dependency!"
    exit 1
  fi

  if ! command -v cargo &> /dev/null
  then
    echo "cargo could not be found, but is a required dependency!"
    echo "Install rustup: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
  fi

  if ! command -v wasm-opt &> /dev/null
  then
    echo "wasm-opt could not be found! Your wasms will not be optimized!"
    echo "Install binaryen: https://github.com/WebAssembly/binaryen"
  fi
}

# DEFAULTS

if [ ! -z $BASE_IBC_PATH ]
then
  BASE_IBC_PATH=$BASE_IBC_PATH
else
  BASE_IBC_PATH="."
fi

BASE_DIR="build"
ANOMA_DIR="anoma"
HERMES_DIR="ibc-rs"

USE_GIT_SSH=false

CHAIN_A_PORT=27657
CHAIN_B_PORT=28657

GITHUB_SSH_URL="git@github.com:"
GITHUB_HTTPS_URL="https://github.com"

ANOMA_REPO="/anoma/anoma.git"
HERMES_REPO="/heliaxdev/ibc-rs.git"

ANOMA_BRANCH="yuji/ibc_test_ibc-rs_v0.14"
HERMES_BRANCH="yuji/v0.14.0_anoma"

# Get CLI Options
while getopts "hs" arg; do
  case $arg in
    (s)
      USE_GIT_SSH=true
      shift $() ;;
    (h)
      usage ;;
    (*)
      usage ;;
  esac
done

ANOMA_GIT_URL="$GITHUB_HTTPS_URL$ANOMA_REPO"
HERMES_GIT_URL="$GITHUB_HTTPS_URL$HERMES_REPO"

[[ $USE_GIT_SSH == true ]] && ANOMA_GIT_URL="$GITHUB_SSH_URL$ANOMA_REPO"
[[ $USE_GIT_SSH == true ]] && HERMES_GIT_URL="$GITHUB_SSH_URL$HERMES_REPO"

check_dependencies

echo "PATH=$BASE_IBC_PATH"

mkdir -p "$BASE_IBC_PATH/$BASE_DIR"
cd "$BASE_IBC_PATH/$BASE_DIR"

# Clone anoma and ibc-rs repositories

# anoma
printf "\e[0m[\e[1;32m+\e[0m] Cloning $ANOMA_GIT_URL\n"
[ ! -d $ANOMA_DIR ] && git clone $ANOMA_GIT_URL || printf "\e[0m[\e[1;33m*\e[0m] Directory anoma exists, skipping...\n\n"

# Hermes (ibc-rs)
printf "\e[0m[\e[1;32m+\e[0m] Cloning $HERMES_GIT_URL\n"
[ ! -d $HERMES_DIR ] && git clone $HERMES_GIT_URL || printf "\e[0m[\e[1;33m*\e[0m] Directory ibc-rs exists, skipping...\n\n"

# Install Anoma
printf "\e[0m[\e[1;32m+\e[0m] Installing Anoma\n\n"
cd $ANOMA_DIR && git checkout $ANOMA_BRANCH && make install && make build-wasm-scripts
# TODO: Initialize each chain and keep track of chain IDs

printf "\e[0m[\e[1;32m+\e[0m] Installing Hermes\n\n"
cd ../$HERMES_DIR && git checkout $HERMES_BRANCH

# TODO: Copy configuration template and add Namada Chain IDS
# TODO: Copy wasms to anoma_wasm/
# TODO: Copy each wallet to anoma_wallet/
# TODO: Create connection and channel

cd ..


echo "Finished!"
exit 0
