defmodule MyApp.Distribution.NodeResponsibilityManager do
  use GenServer
  @behaviour MyApp.Distribution.NodeResponsibilityManagerBehaviour

  @moduledoc """
  Manages node responsibilities by coordinating with MembershipManager and ConsistentHashRing.
  Tracks which nodes are responsible for which keys and rebalances responsibilities when nodes join or leave.
  """

  ## Public API

  @doc """
  Starts the NodeResponsibilityManager.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the node responsible for a given key.
  """
  def get_node_for_key(key) do
    GenServer.call(__MODULE__, {:get_node_for_key, key})
  end

  @doc """
  Rebalances the responsibilities based on the current nodes in the cluster.
  """
  def rebalance do
    GenServer.cast(__MODULE__, :rebalance)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    # Subscribe to membership changes
    MyApp.Cluster.MembershipManager.subscribe()

    # Initialize the consistent hash ring
    nodes = MyApp.Cluster.MembershipManager.nodes()
    {:ok, ring_pid} = MyApp.Distribution.ConsistentHashRing.start_link()

    if nodes != [] do
      Enum.each(nodes, fn node ->
        MyApp.Distribution.ConsistentHashRing.add_node(ring_pid, node)
      end)
    end

    {:ok, %{ring_pid: ring_pid, nodes: nodes}}
  end

  @impl true
  def handle_call({:get_node_for_key, key}, _from, state) do
    case MyApp.Distribution.ConsistentHashRing.which_node(state.ring_pid, key) do
      {:error, :empty_ring} ->
        {:reply, {:error, :no_responsible_node}, state}

      node ->
        IO.puts("Key #{key} is assigned to node #{node}")
        {:reply, {:ok, node}, state}
    end
  end


  @impl true
  def handle_cast(:rebalance, state) do
    # Re-fetch nodes from MembershipManager and update the consistent hash ring
    new_nodes = MyApp.Cluster.MembershipManager.nodes()
    current_nodes = state.nodes

    added_nodes = Enum.filter(new_nodes, fn node -> not Enum.member?(current_nodes, node) end)
    removed_nodes = Enum.filter(current_nodes, fn node -> not Enum.member?(new_nodes, node) end)

    # Add new nodes to the ring and ensure StoreServer is running
    Enum.each(added_nodes, fn node ->
      MyApp.Distribution.ConsistentHashRing.add_node(state.ring_pid, node)
      if node == Node.self() do
        ensure_store_server() # Only start the StoreServer locally
      else
        # Ensure StoreServer is started on remote nodes via RPC
        :rpc.call(node, MyApp.Storage.StoreSupervisor, :start_store_server, [node])
      end
    end)

    # Remove nodes no longer in the cluster
    Enum.each(removed_nodes, fn node ->
      MyApp.Distribution.ConsistentHashRing.remove_node(state.ring_pid, node)
    end)

    {:noreply, %{state | nodes: new_nodes}}
  end




  defp ensure_store_server do
    unless Process.whereis(:store_server) do
      {:ok, _pid} = MyApp.Storage.StoreSupervisor.start_store_server(Node.self())
    end
  end


  # Handle membership change notifications
  @impl true
  def handle_info({:membership_change, _change}, state) do
    rebalance()
    {:noreply, state}
  end
end
