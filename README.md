# anoma-scripts

This is a _WIP_ project for testing and developing scripts.

## ibc-init-local.sh

Initialize two IBC-enabled Namada chains and the `ibc-rs` (Hermes) relayer.

### Usage

Show help:

```bash
cd src
./init-ibc-local.sh -h
```

_NOTE_ You can specify a `BASE_IBC_PATH` environment variable to choose where you want the `build` to be saved.

Install and configure 2 Namada chains with the Hermes relayer:

```bash
./init-ibc-local.sh

# Alternatively, specify that you want git to work over SSH:
./init-ibc-local.sh -s
```

Upon completion, this will generate two files in the `build/` folder:

```bash
.env
config.toml
```

The `.env` file can be copied to the Wallet UI application (in `anoma-apps/packages/anoma-wallet`) to configure it to
work with this set-up.

The `config.toml` is simply the stored, generated information needed to run the chains and relayer from the helper CLI.

## start.sh

_NOTE_ You can specify a `BASE_IBC_PATH` environment variable to choose the `build` directory where the required
`config.toml` is located.

The source chain (e.g., Chain A) and the destination chain (e.g. Chain B), along with Hermes, can be started with the
following commands issued in separate terminals:

```bash
# Start Chain A
./start.sh -a chain-a

# Start Chain B
./start.sh -a chain-b

# Start Hermes
./start.sh -a hermes

# Show usage
./start.sh -h
```
