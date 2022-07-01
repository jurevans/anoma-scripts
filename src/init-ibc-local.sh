#!/bin/bash -e

# init-ibc-local.sh
# Set up a local instance of ibc-rs (Hermes) with two IBC-enabled Namada chains

usage() {
  cat << EOF >&2

Usage: $0 [-h] [-s]

  -s: Use SSH for Github repos (defaults to https)
  -h: Show this message

  *Hint* - Set environment variable BASE_IBC_PATH to point build to a different path. Defaults to $(pwd)/build

  Required packages:
    - git
    - cargo (install via rustup: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh)
    - wasm-opt (part of the binaryen package at https://github.com/WebAssembly/binaryen)
EOF
  exit 1
}

STATUS_INFO="\e[0m[\e[1;32m+\e[0m]"
STATUS_WARN="\e[0m[\e[1;33m!\e[0m]"
STATUS_NOTICE="\e[0m[\e[1;34m*\e[0m]"
STATUS_FAIL="\e[0m[\e[1;31mx\e[0m]"

HERMES_CONFIG_TEMPLATE="config_template.toml"
CHAIN_A_TEMPLATE="#{CHAIN_A_ID}"
CHAIN_B_TEMPLATE="#{CHAIN_B_ID}"

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

BUILD_DIR="$BASE_IBC_PATH/build"
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

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR" && printf "\n$STATUS_WARN Set working directory to $(pwd)\n"

# Clone anoma and ibc-rs repositories

# anoma
printf "\n$STATUS_INFO Cloning $ANOMA_GIT_URL\n"
[ ! -d $BUILD_DIR/$ANOMA_DIR ] &&  git clone  $ANOMA_GIT_URL || \
  printf "$STATUS_NOTICE Directory anoma exists, skipping git clone...\n\n"

# Hermes (ibc-rs)
printf "$STATUS_INFO Cloning $HERMES_GIT_URL\n"
[ ! -d $BUILD_DIR/$HERMES_DIR ] && git clone $HERMES_GIT_URL || \
  printf "$STATUS_NOTICE Directory ibc-rs exists, skipping git clone...\n\n"

# Install Anoma
printf "\e$STATUS_INFO Installing Anoma\n"
cd $BUILD_DIR/$ANOMA_DIR && printf "\n$STATUS_WARN Changed directory to $(pwd)\n\n"

if [ ! -d $BUILD_DIR/$ANOMA_DIR/target/release ]
then
  git checkout $ANOMA_BRANCH && make install && make build-wasm-scripts
else
  printf "$STATUS_NOTICE Anoma release target already present, skipping build\n\n"
fi

# Initialize Namada Chains

# Check to ensure vp_token hash is correct, update if not
VP_TOKEN_OLD_HASH=$( cat $BUILD_DIR/$ANOMA_DIR/$GENESIS_PATH | grep -A 3 "wasm.vp_token" | grep sha256 | cut -d \" -f2 )
VP_TOKEN_HASH=$( cat $BUILD_DIR/$ANOMA_DIR/$WASM_CHECKSUMS_PATH | grep "\"vp_token.wasm\"" | cut -d \" -f4 | cut -d \. -f2 )

if [ $VP_TOKEN_OLD_HASH != $VP_TOKEN_HASH ]
then
  printf "$STATUS_NOTICE $VP_TOKEN_OLD_HASH != $VP_TOKEN_HASH\n"
  printf "$STATUS_NOTICE vp_token hash mismatch, updating...\n"
  sed -i "s/$VP_TOKEN_OLD_HASH/$VP_TOKEN_HASH/g" $BUILD_DIR/$ANOMA_DIR/$GENESIS_PATH
  printf "$STATUS_INFO Successfuly updated $BUILD_DIR/$ANOMA_DIR/$GENESIS_PATH!\n\n"
fi

# CHAIN A
printf "$STATUS_INFO Initializing Chain A\n\n"
CHAIN_A_INIT_STDOUT=$(./target/release/anomac utils init-network \
  --unsafe-dont-encrypt \
  --genesis-path $GENESIS_PATH \
  --chain-prefix anoma-test \
  --localhost \
  --dont-archive \
  --wasm-checksums-path $WASM_CHECKSUMS_PATH)

CHAIN_A_ID=$( echo "${CHAIN_A_INIT_STDOUT%?}" | grep "Derived" | sed 's/Derived chain ID: //g' )
CHAIN_A_PATH="$BASE_IBC_PATH/$ANOMA_DIR/.anoma/$CHAIN_A_ID"

printf "$STATUS_INFO Initialized Chain A: $CHAIN_A_ID\n\n"
CHAIN_A_FAUCET=$( cat $BUILD_DIR/$ANOMA_DIR/.anoma/$CHAIN_A_ID/setup/other/wallet.toml | \
  grep "faucet " |  cut -d \" -f2 )
printf "$STATUS_INFO Setting Chain A faucet to $CHAIN_A_FAUCET\n\n"

# CHAIN B
printf "$STATUS_INFO Initializing Chain B\n\n"
CHAIN_B_INIT_STDOUT=$(./target/release/anomac utils init-network \
  --unsafe-dont-encrypt \
  --genesis-path $GENESIS_PATH \
  --chain-prefix anoma-test \
  --localhost \
  --dont-archive \
  --wasm-checksums-path $WASM_CHECKSUMS_PATH)

CHAIN_B_ID=$( echo "${CHAIN_B_INIT_STDOUT%?}" | grep "Derived" | sed 's/Derived chain ID: //g' )
CHAIN_A_PATH="$BASE_IBC_PATH/$ANOMA_DIR/.anoma/$CHAIN_A_ID"

printf "$STATUS_INFO Initialized Chain B: $CHAIN_B_ID\n\n"
CHAIN_B_FAUCET=$( cat $BUILD_DIR/$ANOMA_DIR/.anoma/$CHAIN_B_ID/setup/other/wallet.toml | \
  grep "faucet " |  cut -d \" -f2 )
printf "$STATUS_INFO Setting Chain B faucet to $CHAIN_B_FAUCET\n\n"

# Chain A - Copy wasms and checksums.json to appropriate directories

cp wasm/*.wasm .anoma/$CHAIN_A_ID/wasm/
cp wasm/checksums.json .anoma/$CHAIN_A_ID/wasm/
cp wasm/*.wasm .anoma/$CHAIN_A_ID/setup/validator-0/.anoma/$CHAIN_A_ID/wasm/
cp wasm/checksums.json .anoma/$CHAIN_A_ID/setup/validator-0/.anoma/$CHAIN_A_ID/wasm/

printf "$STATUS_INFO Copied wasms and checksums.json for $CHAIN_A_ID\n\n"

# Chain B - Copy wasms and checksums.json to appropriate directories

cp wasm/*.wasm .anoma/$CHAIN_B_ID/wasm/
cp wasm/checksums.json .anoma/$CHAIN_B_ID/wasm/
cp wasm/*.wasm .anoma/$CHAIN_B_ID/setup/validator-0/.anoma/$CHAIN_B_ID/wasm/
cp wasm/checksums.json .anoma/$CHAIN_B_ID/setup/validator-0/.anoma/$CHAIN_B_ID/wasm/

printf "$STATUS_INFO Copied wasms and checksums.json for $CHAIN_B_ID\n\n"

# Set up Hermes

printf "$STATUS_INFO Configuring Hermes\n\n"
cd $BUILD_DIR/$HERMES_DIR && printf "$STATUS_WARN Changed directory to $(pwd)\n\n" && \
  git checkout $HERMES_BRANCH

mkdir -p anoma_wasm
printf "$STATUS_INFO Created directory $BUILD_DIR/$HERMES_DIR/anoma_wasm\n"
mkdir -p anoma_wallet/$CHAIN_A_ID
printf "$STATUS_INFO Created directory $BUILD_DIR/$HERMES_DIR/anoma_wallet/$CHAIN_A_ID\n"
mkdir -p anoma_wallet/$CHAIN_B_ID
printf "$STATUS_INFO Created directory $BUILD_DIR/$HERMES_DIR/anoma_wallet/$CHAIN_B_ID\n"

# Copy chain files to Hermes

cp $BUILD_DIR/$ANOMA_DIR/.anoma/$CHAIN_A_ID/setup/other/wallet.toml $BUILD_DIR/$HERMES_DIR/anoma_wallet/$CHAIN_A_ID
printf "$STATUS_INFO Copied $BUILD_DIR/$ANOMA_DIR/.anoma/$CHAIN_A_ID/setup/other/wallet.toml -->\
 $BUILD_DIR/$HERMES_DIR/anoma_wallet/$CHAIN_A_ID\n"

cp $BUILD_DIR/$ANOMA_DIR/.anoma/$CHAIN_B_ID/setup/other/wallet.toml $BUILD_DIR/$HERMES_DIR/anoma_wallet/$CHAIN_B_ID
printf "$STATUS_INFO Copied $BUILD_DIR/$ANOMA_DIR/.anoma/$CHAIN_B_ID/setup/other/wallet.toml -->\
 $BUILD_DIR/$HERMES_DIR/anoma_wallet/$CHAIN_B_ID\n"

cp $BUILD_DIR/$ANOMA_DIR/$WASM_CHECKSUMS_PATH $BUILD_DIR/$HERMES_DIR/anoma_wasm
printf "$STATUS_INFO Copied $BUILD_DIR/$ANOMA_DIR/$WASM_CHECKSUMS_PATH -->\
 $BUILD_DIR/$HERMES_DIR/anoma_wasm/\n"

cp $BUILD_DIR/$ANOMA_DIR/wasm/tx_ibc*.wasm $BUILD_DIR/$HERMES_DIR/anoma_wasm
printf "$STATUS_INFO Copied $BUILD_DIR/$ANOMA_DIR/wasm/tx_ibc*.wasm -->\
 $BUILD_DIR/$HERMES_DIR/anoma_wasm/\n"

# Copy configuration template to Hermes and add Namada Chain IDS

cp $BASE_IBC_PATH/$HERMES_CONFIG_TEMPLATE $BUILD_DIR/$HERMES_DIR/config.toml
printf "$STATUS_INFO Copied $BASE_IBC_PATH/$HERMES_CONFIG_TEMPLATE -->\
 $BUILD_DIR/$HERMES_DIR/config.toml\n"

sed -i "s/$CHAIN_A_TEMPLATE/$CHAIN_A_ID/" $BUILD_DIR/$HERMES_DIR/config.toml
printf "$STATUS_INFO Added $CHAIN_A_ID to $BUILD_DIR/$HERMES_DIR/config.toml\n"
sed -i "s/$CHAIN_B_TEMPLATE/$CHAIN_B_ID/" $BUILD_DIR/$HERMES_DIR/config.toml
printf "$STATUS_INFO Added $CHAIN_B_ID to $BUILD_DIR/$HERMES_DIR/config.toml\n"

# TODO: Create connection and channel

cd $BUILD_DIR && printf "\n$STATUS_WARN Changed directory to $(pwd)\n" 

# Generate a .env file for the Wallet UI:
ENV_PATH=$BUILD_DIR/.env

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
