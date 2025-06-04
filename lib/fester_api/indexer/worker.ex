defmodule FesterAPI.Indexer.Worker do
  use GenServer

  require Logger

  @type address :: String.t()
  @type asset_key :: String.t()
  @type asset_amount :: integer()
  @type assets :: %{asset_key() => asset_amount()}
  @type output :: %{address: address(), assets: assets()}
  @type index :: %{String.t() => output()}

  def child_spec(address: address) do
    %{
      id: :"#{address}",
      start: {__MODULE__, :start_link, [address]},
      type: :worker
    }
  end

  def start_link(address) do
    GenServer.start_link(__MODULE__, address, name: :"#{address}")
  end

  def init(address) do
    Logger.info("Indexer Worker #{address} initialized")

    initial_state = %{index: %{}, address: address}
    {:ok, initial_state}
  end

  def add_to_index(pid, transactions) do
    GenServer.cast(pid, {:add_to_index, transactions})
  end

  def list_assets(pid) do
    GenServer.call(pid, :list_assets)
  end

  def handle_call(:list_assets, _from, %{index: index, address: address} = state) do
    outputs = Enum.filter(index, fn {_ref, output} -> output.address == address end)

    assets =
      outputs
      |> Enum.reduce(%{}, fn {_ref, output}, acc ->
        Enum.reduce(output.assets, acc, fn {asset_key, amount}, inner_acc ->
          Map.update(inner_acc, asset_key, amount, &(&1 + amount))
        end)
      end)

    {:reply, assets, state}
  end

  def handle_cast({:add_to_index, transactions}, %{index: index, address: address} = state) do
    # Only process transactions that involve our address
    relevant_transactions =
      Enum.filter(transactions, fn tx ->
        tx["outputs"]
        |> Enum.filter(fn output -> output["address"] == address end)
      end)

    new_index = process_transactions(relevant_transactions, index)
    {:noreply, %{state | index: new_index}}
  end

  defp process_transactions(transactions, index) do
    Enum.reduce(transactions, index, &process_transaction(&1, &2))
  end

  defp process_transaction(
         %{"id" => tx_id, "inputs" => inputs, "outputs" => outputs},
         index
       ) do
    index = process_transaction_inputs(inputs, index)
    {index, _} = process_transaction_outputs(outputs, tx_id, index)
    index
  end

  defp process_transaction_inputs(inputs, index) do
    Enum.reduce(inputs, index, fn %{"index" => idx, "transaction" => %{"id" => tx_hash}},
                                  acc_index ->
      input_ref = "#{tx_hash}##{idx}"
      Map.delete(acc_index, input_ref)
    end)
  end

  defp process_transaction_outputs(outputs, tx_id, index) do
    Enum.reduce(outputs, {index, 0}, fn output, {acc_index, idx} ->
      new_index = process_output(output, tx_id, idx, acc_index)
      {new_index, idx + 1}
    end)
  end

  defp process_output(output, tx_id, idx, acc_index) do
    output_ref = "#{tx_id}##{idx}"
    %{"address" => address, "value" => value} = output
    assets = build_assets_map(value)

    Map.put(acc_index, output_ref, %{address: address, assets: assets})
  end

  defp build_assets_map(value) do
    Enum.reduce(value, %{}, fn {policy_id, assets}, acc ->
      Enum.reduce(assets, acc, fn {asset_name, amount}, inner_acc ->
        asset_key = build_asset_key(policy_id, asset_name)
        Map.put(inner_acc, asset_key, amount)
      end)
    end)
  end

  defp build_asset_key(policy_id, ""), do: policy_id
  defp build_asset_key(policy_id, asset_name), do: "#{policy_id}.#{asset_name}"
end
