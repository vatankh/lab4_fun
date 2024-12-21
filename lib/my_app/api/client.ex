defmodule MyApp.API.Client do
  @behaviour MyApp.API.ClientBehaviour

  @moduledoc """
  Provides the main API for interacting with the distributed key-value store.
  The Client module routes requests to the appropriate node by querying the
  `NodeResponsibilityManager` for the node responsible for a given key.
  """

  alias MyApp.API.RPC

  def get(key) do
    case MyApp.Distribution.NodeResponsibilityManager.get_node_for_key(key) do
      {:ok, node} ->
        if node == Node.self() do
          ensure_store_server()
          partition_id = Node.self()
          GenServer.call({:global, {:store_server, partition_id}}, {:get, key})
        else
          :rpc.call(node, GenServer, :call, [{:global, {:store_server, node}}, {:get, key}])
        end

      {:error, :no_responsible_node} ->
        {:error, :no_nodes_available}
    end
  end

  def put(key, value) do
    case MyApp.Distribution.NodeResponsibilityManager.get_node_for_key(key) do
      {:ok, node} ->
        if node == Node.self() do
          ensure_store_server()
          partition_id = Node.self()
          GenServer.call({:global, {:store_server, partition_id}}, {:put, key, value})
        else
          :rpc.call(node, GenServer, :call, [{:global, {:store_server, node}}, {:put, key, value}])
        end

      {:error, :no_responsible_node} ->
        {:error, :no_nodes_available}
    end
  end

  defp ensure_store_server() do
    partition_id = Node.self()
    global_name = {:global, {:store_server, partition_id}}

    if :global.whereis_name(global_name) == :undefined do
      case MyApp.Storage.StoreSupervisor.start_store_server(partition_id) do
        {:ok, _pid} ->
          :ok
        {:error, {:already_started, _pid}} ->
          :ok
        {:error, _reason} ->
          :error
      end
    end
  end

  def delete(key) do
    case MyApp.Distribution.NodeResponsibilityManager.get_node_for_key(key) do
      {:ok, node} ->
        if node == Node.self() do
          ensure_store_server()
          partition_id = Node.self()
          GenServer.call({:global, {:store_server, partition_id}}, {:delete, key})
        else
          :rpc.call(node, GenServer, :call, [{:global, {:store_server, node}}, {:delete, key}])
        end

      {:error, :no_responsible_node} ->
        {:error, :no_nodes_available}
    end
  end

end
