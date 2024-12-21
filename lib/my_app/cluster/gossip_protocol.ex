defmodule MyApp.Cluster.GossipProtocol do
  use GenServer

  @moduledoc """
  A module that implements a gossip protocol for cluster membership dissemination.
  Periodically exchanges membership information between nodes to ensure all nodes
  have a consistent view of the cluster.
  """

  @gossip_interval 5_000  # Gossip interval in milliseconds

  ## Public API

  @doc "Starts the GossipProtocol as a GenServer."
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    # Start periodic gossiping
    schedule_gossip()
    {:ok, %{}} # No state is required for this simple implementation
  end

  @impl true
  def handle_info(:gossip, state) do
    # Perform the gossiping operation
    perform_gossip()

    # Schedule the next gossip round
    schedule_gossip()

    {:noreply, state}
  end

  ## Private Functions

  defp schedule_gossip do
    Process.send_after(self(), :gossip, @gossip_interval)
  end

  defp perform_gossip do
    # Get the current cluster nodes from MembershipManager
    nodes = MyApp.Cluster.MembershipManager.nodes()

    # Get the current node
    current_node = Node.self()

    # Skip gossiping if the node list is empty or only contains the current node
    if Enum.empty?(nodes) or (length(nodes) == 1 and current_node in nodes) do
      :ok
    else
      # Select a random peer to gossip with
      case Enum.random(nodes) do
        ^current_node ->
          # Skip if the randomly selected node is the current node
          :ok

        peer ->
          # Send membership information to the peer
          :rpc.call(peer, __MODULE__, :receive_gossip, [current_node, nodes])
      end
    end
  end

  @doc "Handles incoming gossip messages from other nodes."
  def receive_gossip(_sender, remote_nodes) do
    local_nodes = MyApp.Cluster.MembershipManager.nodes()

    # Merge local and remote nodes, and add any new nodes
    new_nodes = Enum.uniq(local_nodes ++ remote_nodes)
    Enum.each(new_nodes, fn node ->
      unless node in local_nodes do
        MyApp.Cluster.MembershipManager.add_node(node)
      end
    end)

    :ok
  end
end
