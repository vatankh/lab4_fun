defmodule MyApp.Cluster.MembershipManager do
  use GenServer

  @moduledoc """
  A module for managing the cluster membership. It keeps track of the nodes
  in the cluster, handles node additions and removals, and notifies subscribers
  of any changes.
  """

  ## Public API

  @doc "Starts the MembershipManager as a GenServer."
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns the current list of nodes in the cluster."
  def nodes do
    GenServer.call(__MODULE__, :get_nodes)
  end

  @doc "Adds a node to the cluster."
  def add_node(node) do
    GenServer.call(__MODULE__, {:add_node, node})
  end

  @doc "Removes a node from the cluster."
  def remove_node(node) do
    GenServer.call(__MODULE__, {:remove_node, node})
  end

  @doc "Subscribes the caller process to membership change notifications."
  def subscribe do
    GenServer.cast(__MODULE__, {:subscribe, self()})
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{nodes: [], subscribers: [MyApp.Distribution.NodeResponsibilityManager]}}
  end

  @impl true
  def handle_call(:get_nodes, _from, state) do
    {:reply, state.nodes, state}
  end

  def handle_call({:add_node, node}, _from, state) do
    if node in state.nodes do
      {:reply, :ok, state}
    else
      new_state = %{state | nodes: [node | state.nodes]}
      notify_subscribers(new_state.subscribers, {:node_added, node})
      {:reply, :ok, new_state}
    end
  end

  def handle_call({:remove_node, node}, _from, state) do
    if node in state.nodes do
      new_state = %{state | nodes: state.nodes -- [node]}
      notify_subscribers(new_state.subscribers, {:node_removed, node})
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :node_not_found}, state}
    end
  end

  @impl true
  def handle_cast({:subscribe, subscriber}, state) do
    new_state = %{state | subscribers: [subscriber | state.subscribers]}
    {:noreply, new_state}
  end

  ## Private Functions

  defp notify_subscribers(subscribers, message) do
    Enum.each(subscribers, fn subscriber ->
      send(subscriber, {:membership_change, message})
    end)
  end
end
