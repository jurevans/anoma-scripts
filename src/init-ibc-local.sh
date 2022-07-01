#!/bin/bash -e

# init-ibc-local.sh
# Set up a local instance of ibc-rs (Hermes) with two IBC-enabled Namada chains

usage() {
  cat << EOF >&2

Usage: $0 [-h] [-s]

  -s: Use SSH for Github repos (defaults to https)
  -h: Show this message

  *Hint* - Set environment variable BASE_IBC_PATH to point build to a different path. Defaults to $(pwd)/build

EOF
  exit 1
}

STATUS_INFO="\e[0m[\e[1;32m+\e[0m]"
STATUS_WARN="\e[0m[\e[1;33m!\e[0m]"
STATUS_ERROR="\e[0m[\e[1;34m*\e[0m]"
STATUS_FAIL="\e[0m[\e[1;31mx\e[0m]"

check_dependencies() {
  if ! command -v git &> /dev/null
  then
    printf "\n$STATUS_FAIL git could not be found, but is a required dependency!\n"
    exit 1
  fi

  if ! command -v cargo &> /dev/null
  then
    printf "\n$STATUS_FAIL cargo could not be found, but is a required dependency!\n"
    echo "Install rustup: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
  fi

  if ! command -v wasm-opt &> /dev/null
  then
    printf "\n$STATUS_FAIL wasm-opt could not be found, but is a required dependency!\n"
    echo "Install binaryen: https://github.com/WebAssembly/binaryen"
    exit 1
  fi
}

# DEFAULTS

if [ ! -z $BASE_IBC_PATH ]
then
  BASE_IBC_PATH=$BASE_IBC_PATH
else
  BASE_IBC_PATH=$(pwd)
fi

BASE_DIR="build"
ANOMA_DIR="anoma"
HERMES_DIR="ibc-rs"

USE_GIT_SSH=false

CHAIN_A_ALIAS="Namada - Instance 1"
CHAIN_A_ID=""
CHAIN_A_PORT=27657
CHAIN_A_FAUCET=""

CHAIN_B_ALIAS="Namada - Instance 2"
CHAIN_B_ID=""
CHAIN_B_PORT=28657
CHAIN_B_FAUCET=""

GITHUB_SSH_URL="git@github.com:"
GITHUB_HTTPS_URL="https://github.com"

ANOMA_REPO="/anoma/anoma.git"
HERMES_REPO="/heliaxdev/ibc-rs.git"

ANOMA_BRANCH="yuji/ibc_test_ibc-rs_v0.14"
HERMES_BRANCH="yuji/v0.14.0_anoma"

GENESIS_PATH="genesis/e2e-tests-single-node.toml"
WASM_CHECKSUMS_PATH="wasm/checksums.json"

LOCALHOST_URL="127.0.0.1"

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
    # TODO: Add option to force-rebuild everything (no skipping of existing builds)
  esac
done

ANOMA_GIT_URL="$GITHUB_HTTPS_URL$ANOMA_REPO"
HERMES_GIT_URL="$GITHUB_HTTPS_URL$HERMES_REPO"

[[ $USE_GIT_SSH == true ]] && ANOMA_GIT_URL="$GITHUB_SSH_URL$ANOMA_REPO"
[[ $USE_GIT_SSH == true ]] && HERMES_GIT_URL="$GITHUB_SSH_URL$HERMES_REPO"

check_dependencies

mkdir -p "$BASE_IBC_PATH/$BASE_DIR"
cd "$BASE_IBC_PATH/$BASE_DIR" && printf "\n$STATUS_WARN Changed directory to $(pwd)\n"

# Clone anoma and ibc-rs repositories

# anoma
printf "\n$STATUS_INFO Cloning $ANOMA_GIT_URL\n"
[ ! -d $ANOMA_DIR ] && git clone $ANOMA_GIT_URL || \
  printf "$STATUS_ERROR Directory anoma exists, skipping git clone...\n\n"

# Hermes (ibc-rs)
printf "$STATUS_INFO Cloning $HERMES_GIT_URL\n"
[ ! -d $HERMES_DIR ] && git clone $HERMES_GIT_URL || \
  printf "$STATUS_ERROR Directory ibc-rs exists, skipping git clone...\n\n"

# Install Anoma
printf "\e$STATUS_INFO Installing Anoma\n"
cd $ANOMA_DIR && printf "\n$STATUS_WARN Changed directory to $(pwd)\n\n" && \
  git checkout $ANOMA_BRANCH && make install && make build-wasm-scripts

# Initialize Namada Chains
cd $BASE_IBC_PATH/$BASE_DIR/$ANOMA_DIR && printf "$STATUS_WARN Changed directory to $(pwd)\n\n"

printf "$STATUS_INFO Initializing Chain A\n\n"
CHAIN_A_INIT_STDOUT=$(./target/release/anomac utils init-network \
  --unsafe-dont-encrypt \
  --genesis-path $GENESIS_PATH \
  --chain-prefix anoma-test \
  --localhost \
  --dont-archive \
  --wasm-checksums-path $WASM_CHECKSUMS_PATH)

CHAIN_A_ID=$( echo "${CHAIN_A_INIT_STDOUT%?}" | grep "Derived" | sed 's/Derived chain ID: //g' )
printf "$STATUS_INFO Initialized Chain A: $CHAIN_A_ID\n\n"

# TODO: Grab faucet address for Chain A

printf "$STATUS_INFO Initializing Chain B\n\n"
CHAIN_B_INIT_STDOUT=$(./target/release/anomac utils init-network \
  --unsafe-dont-encrypt \
  --genesis-path $GENESIS_PATH \
  --chain-prefix anoma-test \
  --localhost \
  --dont-archive \
  --wasm-checksums-path $WASM_CHECKSUMS_PATH)

CHAIN_B_ID=$( echo "${CHAIN_B_INIT_STDOUT%?}" | grep "Derived" | sed 's/Derived chain ID: //g' )
printf "$STATUS_INFO Initialized Chain B: $CHAIN_B_ID\n\n"

# TODO: Grab faucet address for Chain B

# Set up Hermes

printf "$STATUS_INFO Installing Hermes\n\n"
cd ../$HERMES_DIR && printf "\n$STATUS_WARN Changed directory to $(pwd)\n\n" && \
  git checkout $HERMES_BRANCH

# TODO: Copy configuration template to Hermes and add Namada Chain IDS
# TODO: Copy wasms to anoma_wasm/
# TODO: Copy each wallet to anoma_wallet/
# TODO: Create connection and channel

cd $BASE_IBC_PATH/$BUILD_DIR

# TODO: Once chains are configured, generate a .env file for the Wallet UI:

ENV_PATH=$BASE_IBC_PATH/$BASE_DIR/.env

write_env() {
  cat <<EOF > $ENV_PATH
# Chain A
REACT_APP_CHAIN_A_ALIAS=$CHAIN_A_ALIAS
REACT_APP_CHAIN_A_ID=$CHAIN_A_ID
REACT_APP_CHAIN_A_URL=$LOCALHOST_URL
REACT_APP_CHAIN_A_PORT=$CHAIN_A_PORT
REACT_APP_CHAIN_A_FAUCET=$CHAIN_A_FAUCET

# Chain B
REACT_APP_CHAIN_B_ALIAS=$CHAIN_B_ALIAS
REACT_APP_CHAIN_B_ID=$CHAIN_B_ID
REACT_APP_CHAIN_B_URL=$LOCALHOST_URL
REACT_APP_CHAIN_B_PORT=$CHAIN_B_PORT
REACT_APP_CHAIN_B_FAUCET=$CHAIN_B_FAUCET
EOF
}

printf "\n$STATUS_INFO Writing Wallet UI config to $ENV_PATH\n\n"

write_env

echo "Success!"
exit 0
