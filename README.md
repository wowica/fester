# Fester

<p align="center">
<img src="docs/fester-logo.png" alt="Fester Logo" width="200" />
</p>

An Elixir based Cardano Indexer.

⚠️ Attention:

- [x] Highly experimental POC.
- [x] Developed against preview testnet.
- [x] Not production ready.
- [x] Production use is not recommended.

## How to run

Set a `OGMIOS_URL` environment variable to the URL of the OGMIOS instance you want to connect to.

```bash
export OGMIOS_URL=http://localhost:1337
```

Run the application with `iex -S mix`. This should immediately start the syncing process. Defaults to syncing from the origin so it will take a while to catch up. 

To sync from a specific point in the chain, set the `sync_from` option on `lib/fester/chain_sync.ex`.

Listing assets for a particular address:

```elixir
Fester.Indexer.list_assets_by_address("addr_test1...")
```

or a straight-up list of [UTXOs](./lib/fester/utxo.ex):

```elixir
Fester.Indexer.list_utxos_by_address("addr_test1...")
```


## HTTP API

A GET request to the `/api/address/$ADDR/assets` endpoint returns the assets for an address.
