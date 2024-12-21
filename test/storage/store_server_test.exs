defmodule MyApp.Storage.StoreServerTest do
  use ExUnit.Case, async: true

  alias MyApp.Storage.StoreServer

  @moduledoc """
  Tests for the StoreServer module.
  """

  setup do
    {:ok, pid} = StoreServer.start_link(:test_partition)
    %{pid: pid}
  end

  describe "put/3" do
    test "stores a key-value pair", %{pid: pid} do
      assert :ok == StoreServer.put(pid, "key1", "value1")
    end
  end

  describe "get/2" do
    test "retrieves the value for an existing key", %{pid: pid} do
      StoreServer.put(pid, "key1", "value1")
      assert "value1" == StoreServer.get(pid, "key1")
    end

    test "returns :not_found for a missing key", %{pid: pid} do
      assert :not_found == StoreServer.get(pid, "non_existent_key")
    end
  end

  describe "delete/2" do
    test "removes an existing key", %{pid: pid} do
      StoreServer.put(pid, "key1", "value1")
      assert :ok == StoreServer.delete(pid, "key1")
      assert :not_found == StoreServer.get(pid, "key1")
    end

    test "returns :ok even if the key does not exist", %{pid: pid} do
      assert :ok == StoreServer.delete(pid, "non_existent_key")
    end
  end

  describe "concurrent operations" do
    test "handles concurrent reads and writes", %{pid: pid} do
      tasks = Enum.map(1..100, fn i ->
        Task.async(fn ->
          StoreServer.put(pid, "key_#{i}", "value_#{i}")
          StoreServer.get(pid, "key_#{i}")
        end)
      end)

      results = Enum.map(tasks, &Task.await/1)

      assert Enum.all?(results, fn result -> String.starts_with?(result, "value_") end)
    end
  end
end
