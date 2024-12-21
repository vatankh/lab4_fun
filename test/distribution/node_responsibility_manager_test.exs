defmodule MyApp.Distribution.NodeResponsibilityManagerTest do
  use ExUnit.Case, async: true

  alias MyApp.Distribution.NodeResponsibilityManager
  alias MyApp.Cluster.MembershipManager
  alias MyApp.Distribution.ConsistentHashRing

  setup do
    # Start the MembershipManager mock
    {:ok, _membership_manager} = MembershipManager.start_link(%{})

    # Start the NodeResponsibilityManager
    {:ok, manager_pid} = NodeResponsibilityManager.start_link([])

    {:ok, %{manager_pid: manager_pid}}
  end

  test "get_node_for_key returns the correct node for a key", %{manager_pid: _pid} do
    # Add some mock nodes to the membership manager
    MembershipManager.add_node(:node1)
    MembershipManager.add_node(:node2)
    MembershipManager.add_node(:node3)

    # Trigger a rebalance to update the consistent hash ring
    NodeResponsibilityManager.rebalance()

    # Retrieve nodes for specific keys
    node_for_key1 = NodeResponsibilityManager.get_node_for_key("key1")
    node_for_key2 = NodeResponsibilityManager.get_node_for_key("key2")
    node_for_key3 = NodeResponsibilityManager.get_node_for_key("key3")

    # Assert that each key is assigned to one of the nodes
    assert node_for_key1 in [:node1, :node2, :node3]
    assert node_for_key2 in [:node1, :node2, :node3]
    assert node_for_key3 in [:node1, :node2, :node3]
  end

  test "rebalance updates consistent hash ring when nodes are added", %{manager_pid: _pid} do
    # Add a node to the membership manager
    MembershipManager.add_node(:node1)
    NodeResponsibilityManager.rebalance()

    # Check the responsible node for a key
    node_before = NodeResponsibilityManager.get_node_for_key("key1")
    assert node_before == :node1

    # Add a new node and rebalance
    MembershipManager.add_node(:node2)
    NodeResponsibilityManager.rebalance()

    # Ensure the ring is updated
    node_after = NodeResponsibilityManager.get_node_for_key("key1")
    assert node_after in [:node1, :node2]
  end

  test "rebalance updates consistent hash ring when nodes are removed", %{manager_pid: _pid} do
    # Add nodes to the membership manager
    MembershipManager.add_node(:node1)
    MembershipManager.add_node(:node2)
    NodeResponsibilityManager.rebalance()

    # Check responsible node before removal
    node_before = NodeResponsibilityManager.get_node_for_key("key1")
    assert node_before in [:node1, :node2]

    # Remove a node and rebalance
    MembershipManager.remove_node(:node1)
    NodeResponsibilityManager.rebalance()

    # Check responsible node after removal
    node_after = NodeResponsibilityManager.get_node_for_key("key1")
    assert node_after == :node2
  end
end
