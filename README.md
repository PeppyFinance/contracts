# Peppy Finance Smart Contracts

## Installation

1. First get foundry via [getfoundry.sh](https://getfoundry.sh).

2. Second run `foundryup` to install the foundry toolchain.

3. Now we can build the project running `forge build`.

4. For local development make sure to add an `.env` and add the following env vars:

```bash
RPC_URL=http://localhost:8545/
PRIVATE_KEY=my-priv-key
PUBLIC_ADDR=my-pub-key
PYTH_ADDR=pyth-addr
```

5. run `anvil` with the `--fork-url` flag and specify which chain should be forked. It is then important
   to match `PYTH_ADDR` with the actual address on the forked chain.

## Testing and logging

You can run foundry tests with `forge test`.

You can optionally log state for simulation tests with `LOG_SIMULATION=true forge test`

## Local Deployment

start anvil with `anvil --dump-state 'state/deployment.state`

run deployment script with './deploy-local.sh', make sure to have a .env file.

Next time, you can load the deployment in you anvil with  `anvil --load-state 'state/deployment.state`