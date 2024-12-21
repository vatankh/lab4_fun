defmodule MyApp.Cluster.GossipProtocolTest do
  use ExUnit.Case, async: true

  alias MyApp.Cluster.{GossipProtocol, MembershipManager}

  setup do
    # Start the MembershipManager for each test
    {:ok, _membership_pid} = start_supervised({MembershipManager, []})
    # Start the GossipProtocol for each test
    {:ok, _gossip_pid} = start_supervised({GossipProtocol, []})

    # Initially, let's assume the cluster has only the current node
    current_node = Node.self()
    :ok = MembershipManager.add_node(current_node)

    [current_node: current_node]
  end

  test "GossipProtocol merges remote nodes on receive_gossip", %{current_node: current_node} do
    # Initially, we have only our current_node in membership
    assert MembershipManager.nodes() == [current_node]

    # Simulate receiving gossip from a remote node set
    remote_nodes = [:node_a@host, :node_b@host]
    :ok = GossipProtocol.receive_gossip(:node_x@host, remote_nodes)

    # The membership manager should now include the new nodes
    nodes = MembershipManager.nodes()
    assert Enum.sort(nodes) == Enum.sort([current_node | remote_nodes])
  end

  test "GossipProtocol schedules gossiping messages periodically" do
    gossip_pid = Process.whereis(MyApp.Cluster.GossipProtocol)

    # Set a trace on the gossip process to observe message reception
    :erlang.trace(gossip_pid, true, [:receive])

    # Wait long enough for the gossip interval to pass
    # @gossip_interval is 5_000 ms, so wait slightly longer
    Process.sleep(6_000)

    # Now check if we received a trace event indicating that :gossip was received
    received_gossip =
      receive do
        {:trace, ^gossip_pid, :receive, :gossip} -> true
      after
        1_000 -> false
      end

    assert received_gossip, "Expected to trace a :gossip message"
  end


  test "receive_gossip does not add duplicates", %{current_node: current_node} do
    # Add another node
    :ok = MembershipManager.add_node(:node_a@host)

    # Current membership: current_node and :node_a@host
    assert Enum.sort(MembershipManager.nodes()) == Enum.sort([current_node, :node_a@host])

    # Receiving gossip that includes the same nodes shouldn't change membership
    :ok = GossipProtocol.receive_gossip(:node_x@host, [:node_a@host, current_node])
    assert Enum.sort(MembershipManager.nodes()) == Enum.sort([current_node, :node_a@host])
  end
end
