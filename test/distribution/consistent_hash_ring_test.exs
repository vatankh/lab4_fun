defmodule MyApp.Distribution.ConsistentHashRingTest do
  use ExUnit.Case, async: true

  alias MyApp.Distribution.ConsistentHashRing

  setup do
    # Start a fresh instance of the ConsistentHashRing GenServer for each test
    {:ok, pid} = ConsistentHashRing.start_link()
    %{ring: pid}
  end

  describe "add_node/2" do
    test "adds a node to the ring", %{ring: pid} do
      assert :ok == ConsistentHashRing.add_node(pid, :node1)

      # Retrieve the current state of the ring
      state = ConsistentHashRing.ring_state(pid)

      # Ensure the ring contains the node with its hash
      node_hash = :erlang.phash2(:node1)
      assert state.ring[node_hash] == :node1
      assert node_hash in state.sorted_keys
    end

    test "adds multiple nodes to the ring", %{ring: pid} do
      assert :ok == ConsistentHashRing.add_node(pid, :node1)
      assert :ok == ConsistentHashRing.add_node(pid, :node2)

      state = ConsistentHashRing.ring_state(pid)
      assert Map.keys(state.ring) |> length() == 2
      assert Enum.count(state.sorted_keys) == 2
    end
  end

  describe "remove_node/2" do
    test "removes a node from the ring", %{ring: pid} do
      ConsistentHashRing.add_node(pid, :node1)
      ConsistentHashRing.add_node(pid, :node2)

      assert :ok == ConsistentHashRing.remove_node(pid, :node1)

      state = ConsistentHashRing.ring_state(pid)
      assert Map.has_key?(state.ring, :node1_hash) == false
      assert length(state.sorted_keys) == 1
    end
  end

  describe "which_node/2" do
    test "finds the correct node for a key", %{ring: pid} do
      ConsistentHashRing.add_node(pid, :node1)
      ConsistentHashRing.add_node(pid, :node2)
      ConsistentHashRing.add_node(pid, :node3)

      key = "my_key"
      responsible_node = ConsistentHashRing.which_node(pid, key)

      assert responsible_node in [:node1, :node2, :node3]
    end

    test "wraps around when the key hash is greater than all node hashes", %{ring: pid} do
      ConsistentHashRing.add_node(pid, :node1)
      ConsistentHashRing.add_node(pid, :node2)

      # Add a key whose hash is likely higher than all node hashes
      key = :erlang.phash2("unlikely_high_key", 1_000_000_000)
      responsible_node = ConsistentHashRing.which_node(pid, key)

      # Should wrap around to the first node in sorted_keys
      state = ConsistentHashRing.ring_state(pid)
      first_node = state.ring[hd(state.sorted_keys)]
      assert responsible_node == first_node
    end
  end

  describe "ring_state/1" do
    test "returns the current state of the ring", %{ring: pid} do
      ConsistentHashRing.add_node(pid, :node1)
      ConsistentHashRing.add_node(pid, :node2)

      state = ConsistentHashRing.ring_state(pid)
      assert is_map(state)
      assert Map.has_key?(state, :ring)
      assert Map.has_key?(state, :sorted_keys)
    end
  end
end
