defmodule MyApp.Cluster.MembershipManagerTest do
  use ExUnit.Case

  alias MyApp.Cluster.MembershipManager

  setup do
    # Start the MembershipManager fresh for each test
    {:ok, _pid} = MembershipManager.start_link([])
    :ok
  end

  describe "MembershipManager functionality" do
    test "initial nodes list is empty" do
      assert MembershipManager.nodes() == []
    end

    test "add_node/1 adds a node to the cluster" do
      :ok = MembershipManager.add_node(:node1)
      assert :node1 in MembershipManager.nodes()
    end

    test "add_node/1 does not add duplicate nodes" do
      :ok = MembershipManager.add_node(:node1)
      :ok = MembershipManager.add_node(:node1)
      assert MembershipManager.nodes() == [:node1]
    end

    test "remove_node/1 removes a node from the cluster" do
      :ok = MembershipManager.add_node(:node1)
      :ok = MembershipManager.add_node(:node2)

      :ok = MembershipManager.remove_node(:node1)
      assert :node1 not in MembershipManager.nodes()
      assert :node2 in MembershipManager.nodes()
    end

    test "remove_node/1 returns error if node is not found" do
      assert {:error, :node_not_found} = MembershipManager.remove_node(:nonexistent_node)
    end

    test "subscribers receive notifications on node addition" do
      test_process = self()
      MembershipManager.subscribe()

      :ok = MembershipManager.add_node(:node1)

      assert_receive {:membership_change, {:node_added, :node1}}, 100
    end

    test "subscribers receive notifications on node removal" do
      test_process = self()
      MembershipManager.subscribe()

      :ok = MembershipManager.add_node(:node1)
      :ok = MembershipManager.remove_node(:node1)

      assert_receive {:membership_change, {:node_removed, :node1}}, 100
    end

    test "multiple subscribers receive notifications" do
      parent = self()

      # Subscribe the main test process
      MembershipManager.subscribe()

      # Simulate a second subscriber process
      spawn(fn ->
        MembershipManager.subscribe()
        send(parent, :subscribed)

        # Wait for membership change notifications
        receive do
          {:membership_change, _msg} -> :ok
        after
          200 -> send(parent, :notification_failed)
        end
      end)

      # Wait for the spawned process to subscribe
      assert_receive :subscribed, 200

      # Now both the main test process and the spawned process are subscribed
      :ok = MembershipManager.add_node(:node1)

      # Main process should now receive the notification since it's subscribed
      assert_receive {:membership_change, {:node_added, :node1}}, 200
    end
  end
end
