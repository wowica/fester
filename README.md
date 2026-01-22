# Fester

<p align="center">
<img src="docs/fester-logo.png" alt="Fester Logo" width="200" />
</p>

An Elixir based Cardano Indexer.

## Roadmap 

### Phase 1 - MVP 
- [x] Index outputs by address.
- [x] Persist to local database (SQLite)
- [x] HTTP endpoint for querying assets by address
- [x] Metrics printed to standard out
- [x] Tested with Preview + Mainnet
- [x] Run with Docker

### Phase 2
- [ ] Ability to stop/resume syncing.
- [ ] In-memory indexer (look into ETS)
- [ ] Metrics LiveView Dashboard
- [ ] Metrics exported to Prometheus

### Phase 3
- [ ] Clustered indexer with (BEAM) process distribution
- [ ] Adjust persistence to fit with a clustered environment (look into Mnesia)
- [ ] Index more data (TBD)
- [ ] Add more endpoints (TBD)

## How to run

Set a `OGMIOS_URL` environment variable to the WebSocket URL of the OGMIOS instance you want to connect to.

```bash
export OGMIOS_URL=ws://localhost:1337
```

Setup the database with `mix ecto.migrate` and then run the application with `iex -S mix`. This should immediately start the syncing process. Defaults to syncing from the origin so it will take a while to catch up.

To sync from a specific point in the chain, set the `sync_from` option on `lib/fester/chain_sync.ex`.

Listing assets for a particular address:

```elixir
Fester.Indexer.list_assets_by_address("addr_test1...")
```

or a straight-up list of [UTXOs](./lib/fester/utxo.ex):

```elixir
Fester.Indexer.list_utxos_by_address("addr_test1...")
```

## Running with Docker

Build the Docker image with:

```bash
docker build -t fester .
```

Populate the proper environment variables in `docker_run.sh` and run it with:

```bash
./docker_run.sh
```


## HTTP API

A GET request to the `/api/address/$ADDR/assets` endpoint returns the assets for an address.
