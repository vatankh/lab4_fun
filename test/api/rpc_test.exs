defmodule MyApp.API.RPCTest do
  use ExUnit.Case, async: true

  alias MyApp.API.RPC

  defmodule TestModule do
    def greet(name), do: "Hello, #{name}!"
    def cast_action(_arg), do: :ok
  end

  describe "call_remote/4" do
    test "returns {:ok, result} on success" do
      node = Node.self()
      assert {:ok, "Hello, world!"} = RPC.call_remote(node, TestModule, :greet, ["world"])
    end

    test "returns {:error, reason} on failure" do
      node = Node.self()
      result = RPC.call_remote(node, NonExistentModule, :non_existent_func, [])
      # We expect something like {:badrpc, {:EXIT, {:undef, ...}}} inside the {:error, ...} tuple
      assert {:error, {:EXIT, {:undef, _}}} = result
    end
  end

  describe "cast_remote/4" do
    test "returns :ok on success" do
      node = Node.self()
      assert :ok = RPC.cast_remote(node, TestModule, :cast_action, [:some_arg])
    end

    test "returns {:error, reason} if the function doesn't exist" do
      node = Node.self()
      result = RPC.cast_remote(node, NonExistentModule, :non_existent_func, [])
      assert {:error, {:EXIT, {:undef, _}}} = result
    end
  end
end
