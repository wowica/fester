defmodule FesterAPI.Indexer do
  use GenServer

  require Logger

  @type address :: String.t()
  @type asset_key :: String.t()
  @type asset_amount :: integer()
  @type assets :: %{asset_key() => asset_amount()}
  @type output :: %{address: address(), assets: assets()}
  @type index :: %{String.t() => output()}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    Logger.info("Indexer initialized")
    initial_state = %{addresses: Keyword.get(opts, :addresses, []), index: %{}}
    {:ok, initial_state}
  end

  def add_to_index(pid \\ __MODULE__, block) do
    GenServer.cast(pid, {:add_to_index, block})
  end

  def query_address(pid \\ __MODULE__, address) do
    GenServer.call(pid, {:query_address, address})
  end

  def handle_call({:query_address, address}, _from, state) do
    outputs = Enum.filter(state[:index], fn {_ref, output} -> output.address == address end)

    assets =
      outputs
      |> Enum.reduce(%{}, fn {_ref, output}, acc ->
        Enum.reduce(output.assets, acc, fn {asset_key, amount}, inner_acc ->
          Map.update(inner_acc, asset_key, amount, &(&1 + amount))
        end)
      end)

    {:reply, assets, state}
  end

  def handle_cast({:add_to_index, %{"transactions" => transactions}}, state) do
    new_index = process_block_transactions(transactions, state.index, state.addresses)
    # IO.inspect(new_index, label: "new_index")
    {:noreply, %{state | index: new_index}}
  end

  @spec process_block_transactions([map()], index(), [address()]) :: index()
  defp process_block_transactions(transactions, index, addresses) do
    Enum.reduce(transactions, index, &process_transaction(&1, &2, addresses))
  end

  @spec process_transaction(map(), index(), [address()]) :: index()
  defp process_transaction(
         %{"id" => tx_id, "inputs" => inputs, "outputs" => outputs},
         index,
         addresses
       ) do
    index = process_transaction_inputs(inputs, index)
    {index, _} = process_transaction_outputs(outputs, tx_id, index, addresses)
    index
  end

  defp process_transaction_inputs(inputs, index) do
    Enum.reduce(inputs, index, fn %{"index" => idx, "transaction" => %{"id" => tx_hash}},
                                  acc_index ->
      input_ref = "#{tx_hash}##{idx}"
      Map.delete(acc_index, input_ref)
    end)
  end

  @spec process_transaction_outputs([map()], String.t(), index(), [address()]) ::
          {index(), integer()}
  defp process_transaction_outputs(outputs, tx_id, index, addresses) do
    Enum.reduce(outputs, {index, 0}, fn output, {acc_index, index} ->
      new_index = process_output(output, tx_id, index, acc_index, addresses)
      {new_index, index + 1}
    end)
  end

  @spec process_output(map(), String.t(), integer(), index(), [address()]) :: index()
  defp process_output(_output, _tx_id, _idx, _acc_index, _addresses)

  defp process_output(output, tx_id, idx, acc_index, []) do
    output_ref = "#{tx_id}##{idx}"
    %{"address" => address, "value" => value} = output
    assets = build_assets_map(value)

    Map.put(acc_index, output_ref, %{address: address, assets: assets})
  end

  defp process_output(output, tx_id, idx, acc_index, addresses) do
    output_ref = "#{tx_id}##{idx}"
    %{"address" => address, "value" => value} = output

    if address in addresses do
      assets = build_assets_map(value)
      Map.put(acc_index, output_ref, %{address: address, assets: assets})
    else
      acc_index
    end
  end

  @spec build_assets_map(map()) :: assets()
  defp build_assets_map(value) do
    Enum.reduce(value, %{}, fn {policy_id, assets}, acc ->
      Enum.reduce(assets, acc, fn {asset_name, amount}, inner_acc ->
        asset_key = build_asset_key(policy_id, asset_name)
        Map.put(inner_acc, asset_key, amount)
      end)
    end)
  end

  @spec build_asset_key(String.t(), String.t()) :: asset_key()
  defp build_asset_key(policy_id, ""), do: policy_id
  defp build_asset_key(policy_id, asset_name), do: "#{policy_id}.#{asset_name}"
end
