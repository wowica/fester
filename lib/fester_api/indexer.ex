defmodule FesterAPI.Indexer do
  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    Logger.info("Indexer initialized")
    {:ok, opts}
  end

  def add_to_index(pid \\ __MODULE__, block) do
    GenServer.cast(pid, {:add_to_index, block})
  end

  def handle_cast({:add_to_index, block}, state) do
    Logger.info("add_to_index #{block["height"]}")

    transaction = hd(block["transactions"])
    tx_id = transaction["id"]

    IO.puts("\n\nCreate these outputs:")

    Enum.reduce(transaction["outputs"], 0, fn output, acc ->
      output_ref = tx_id <> "#" <> Integer.to_string(acc)
      IO.puts(output_ref)
      # output_ref is the utxo produced by this transaction

      %{
        "address" => address,
        "value" => %{"ada" => %{"lovelace" => _lovelace}} = value
      } = output

      IO.puts("Address: #{inspect(address)}")

      for {policy_id, assets} <- value do
        for {asset_name, amount} <- assets do
          IO.puts(
            "\t#{policy_id}#{if asset_name != "", do: ".#{asset_name}", else: ""}: #{inspect(amount)}"
          )
        end
      end

      acc + 1
    end)

    IO.puts("\n\nDelete these inputs:")

    Enum.each(transaction["inputs"], fn input ->
      %{
        "index" => input_idx,
        "transaction" => %{
          "id" => tx_input
        }
      } = input

      input_ref = tx_input <> "#" <> Integer.to_string(input_idx)
      IO.inspect(input_ref)
    end)

    {:noreply, state}
  end
end
