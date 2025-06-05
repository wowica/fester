# Fester

<p align="center">
<img src="docs/fester-logo.png" alt="Fester Logo" width="200" />
</p>

An Elixir based Cardano Indexer.

⚠️ Attention:

- [x] Highly experimental POC.
- [x] Not production ready.
- [x] Production use is not recommended.
- [x] No usar en producción.

## How to run

Set a `OGMIOS_URL` environment variable to the URL of the OGMIOS instance you want to sync from.

```bash
export OGMIOS_URL=http://localhost:1337
```

Manually set `@addresses` in `lib/fester/indexer/supervisor.ex` to the addresses you want to index.

```elixir
@addresses [
  "addr_1...",
  "addr_2...",
  "addr_3...",
  ...
]
```

Run the application with `iex -S mix`. This should immediately start syncing with the chain and indexing the assets for each one of the addresses you've set. 

Depending on which network you're using, it might take a while to catch up. 😴

Listing assets for a particular address:

```elixir
Fester.Indexer.list_assets("addr_1...")
```

Example output:

```bash
%{
  "088da4aba74c8c6a1438448f10dc0ef37c6af91fb4575741b6a3580e.42616e616e6173" => 666,
  "ada.lovelace" => 802159390
}
```