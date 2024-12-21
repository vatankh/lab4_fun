defmodule MyApp.API.ClientTest do
  use ExUnit.Case, async: true
  import Mox

  alias MyApp.API.Client
  alias MyApp.Distribution.NodeResponsibilityManagerMock
  alias MyApp.API.RPCMock

  # Make sure unexpected calls raise errors
  setup :verify_on_exit!

  setup do
    # Override the application environment so Client uses our mocks
    Application.put_env(:my_app, :node_responsibility_manager, NodeResponsibilityManagerMock)
    Application.put_env(:my_app, :rpc_module, RPCMock)

    # Undo the overrides after each test
    on_exit(fn ->
      Application.delete_env(:my_app, :node_responsibility_manager)
      Application.delete_env(:my_app, :rpc_module)
    end)

    :ok
  end

  describe "get/1" do
    test "returns {:ok, value} when node manager and RPC succeed" do
      key = "some_key"

      NodeResponsibilityManagerMock
      |> expect(:get_node_for_key, fn ^key ->
        {:ok, :node_1}
      end)

      RPCMock
      |> expect(:call_remote, fn :node_1, MyApp.Storage.StoreServer, :get, [^key] ->
        {:ok, "some_value"}
      end)

      assert {:ok, "some_value"} = Client.get(key)
    end

    test "returns error tuple if node manager returns error" do
      key = "some_key"

      NodeResponsibilityManagerMock
      |> expect(:get_node_for_key, fn ^key ->
        {:error, :no_nodes_available}
      end)

      # No RPC call expected, because we fail early.
      assert {:error, :no_nodes_available} = Client.get(key)
    end

    test "returns error tuple if RPC fails" do
      key = "some_key"

      NodeResponsibilityManagerMock
      |> expect(:get_node_for_key, fn ^key ->
        {:ok, :node_1}
      end)

      RPCMock
      |> expect(:call_remote, fn :node_1, MyApp.Storage.StoreServer, :get, [^key] ->
        {:error, :rpc_issue}
      end)

      assert {:error, :rpc_issue} = Client.get(key)
    end
  end

  describe "put/2" do
    test "returns :ok when node manager and RPC succeed" do
      key = "some_key"
      value = "some_value"

      NodeResponsibilityManagerMock
      |> expect(:get_node_for_key, fn ^key ->
        {:ok, :node_1}
      end)

      RPCMock
      |> expect(:cast_remote, fn :node_1, MyApp.Storage.StoreServer, :put, [^key, ^value] ->
        :ok
      end)

      assert :ok = Client.put(key, value)
    end

    test "returns error tuple if node manager returns error" do
      key = "some_key"
      value = "some_value"

      NodeResponsibilityManagerMock
      |> expect(:get_node_for_key, fn ^key ->
        {:error, :no_nodes_available}
      end)

      assert {:error, :no_nodes_available} = Client.put(key, value)
    end

    test "returns error tuple if RPC fails" do
      key = "some_key"
      value = "some_value"

      NodeResponsibilityManagerMock
      |> expect(:get_node_for_key, fn ^key ->
        {:ok, :node_1}
      end)

      RPCMock
      |> expect(:cast_remote, fn :node_1, MyApp.Storage.StoreServer, :put, [^key, ^value] ->
        {:error, :rpc_issue}
      end)

      assert {:error, :rpc_issue} = Client.put(key, value)
    end
  end

  describe "delete/1" do
    test "returns {:ok, result} if RPC is successful" do
      key = "some_key"

      NodeResponsibilityManagerMock
      |> expect(:get_node_for_key, fn ^key ->
        {:ok, :node_1}
      end)

      RPCMock
      |> expect(:call_remote, fn :node_1, MyApp.Storage.StoreServer, :delete, [^key] ->
        {:ok, :deleted}
      end)

      assert {:ok, :deleted} = Client.delete(key)
    end

    test "returns error tuple if node manager returns error" do
      key = "some_key"

      NodeResponsibilityManagerMock
      |> expect(:get_node_for_key, fn ^key ->
        {:error, :no_nodes_available}
      end)

      assert {:error, :no_nodes_available} = Client.delete(key)
    end

    test "returns error tuple if RPC fails" do
      key = "some_key"

      NodeResponsibilityManagerMock
      |> expect(:get_node_for_key, fn ^key ->
        {:ok, :node_1}
      end)

      RPCMock
      |> expect(:call_remote, fn :node_1, MyApp.Storage.StoreServer, :delete, [^key] ->
        {:error, :rpc_issue}
      end)

      assert {:error, :rpc_issue} = Client.delete(key)
    end
  end
end
