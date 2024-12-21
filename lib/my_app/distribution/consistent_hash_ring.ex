defmodule MyApp.Distribution.ConsistentHashRing do
  use GenServer

  @moduledoc """
  Implements a consistent hash ring for distributing keys across nodes.
  """

  # Public API

  @doc """
  Starts the `ConsistentHashRing` server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  @doc """
  Adds a node to the hash ring.
  """
  def add_node(pid, node) do
    GenServer.call(pid, {:add_node, node})
  end

  @doc """
  Removes a node from the hash ring.
  """
  def remove_node(pid, node) do
    GenServer.call(pid, {:remove_node, node})
  end

  @doc """
  Determines which node is responsible for a given key.
  """
  def which_node(pid, key) do
    GenServer.call(pid, {:which_node, key})
  end

  @doc """
  Returns the current state of the ring (for debugging).
  """
  def ring_state(pid) do
    GenServer.call(pid, :ring_state)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Initialize the consistent hash ring state
    {:ok, %{ring: %{}, sorted_keys: []}}
  end

  @impl true
  def handle_call({:add_node, node}, _from, state) do
    {updated_ring, updated_keys} = add_node_to_ring(state, node)
    {:reply, :ok, %{state | ring: updated_ring, sorted_keys: updated_keys}}
  end

  @impl true
  def handle_call({:remove_node, node}, _from, state) do
    {updated_ring, updated_keys} = remove_node_from_ring(state, node)
    {:reply, :ok, %{state | ring: updated_ring, sorted_keys: updated_keys}}
  end

  @impl true
  def handle_call({:which_node, key}, _from, state) do
    node = find_responsible_node(state, key)
    {:reply, node, state}
  end

  @impl true
  def handle_call(:ring_state, _from, state) do
    {:reply, state, state}
  end

  # Internal Functions

  defp add_node_to_ring(%{ring: ring, sorted_keys: sorted_keys}, node) do
    hash = :erlang.phash2(node)
    updated_ring = Map.put(ring, hash, node)
    updated_keys = Enum.sort([hash | sorted_keys])
    {updated_ring, updated_keys}
  end

  defp remove_node_from_ring(%{ring: ring, sorted_keys: sorted_keys}, node) do
    hash = :erlang.phash2(node)
    updated_ring = Map.delete(ring, hash)
    updated_keys = Enum.filter(sorted_keys, fn key -> key != hash end)
    {updated_ring, updated_keys}
  end

  defp find_responsible_node(%{ring: ring, sorted_keys: sorted_keys}, key) do
    case sorted_keys do
      [] ->
        # Return a default or error when the ring is empty
        {:error, :empty_ring}

      _ ->
        hash = :erlang.phash2(key)
        case Enum.find(sorted_keys, fn key_hash -> key_hash >= hash end) do
          nil -> ring[hd(sorted_keys)] # Wrap around to the first node
          responsible_key -> ring[responsible_key]
        end
    end
  end
end
