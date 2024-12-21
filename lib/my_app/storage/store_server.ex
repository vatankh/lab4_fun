defmodule MyApp.Storage.StoreServer do
  use GenServer
  require Logger

  @moduledoc """
  A GenServer responsible for managing a local key-value store.
  """

  # Public API

  @doc """
  Starts the StoreServer process with an optional initial state.
  """
  def start_link(partition_id, opts \\ []) do
    name = {:global, {:store_server, partition_id}}
    opts = Keyword.put_new(opts, :name, name)
    GenServer.start_link(__MODULE__, %{partition_id: partition_id, data: %{}}, opts)
  end

  @doc """
  Retrieves a value associated with the given key.
  """
  def get(pid, key) do
    GenServer.call(pid, {:get, key})
  end

  @doc """
  Stores a key-value pair.
  """
  def put(pid, key, value) do
    GenServer.call(pid, {:put, key, value})
  end

  @doc """
  Deletes a key-value pair by key.
  """
  def delete(pid, key) do
    GenServer.call(pid, {:delete, key})
  end

  @doc """
  Retrieves the partition ID of the StoreServer.
  """
  def get_partition_id(pid) do
    GenServer.call(pid, :get_partition_id)
  end

  # GenServer Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:get_partition_id, _from, state) do
    {:reply, state.partition_id, state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    value = Map.get(state.data, key, :not_found)
    {:reply, value, state}
  end

  @impl true
  def handle_call({:put, key, value}, _from, state) do
    new_data = Map.put(state.data, key, value)
    new_state = %{state | data: new_data}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:delete, key}, _from, state) do
    new_data = Map.delete(state.data, key)
    new_state = %{state | data: new_data}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(other, _from, state) do
    {:reply, {:error, :unknown_operation}, state}
  end
end
