defmodule MyApp.API.RPC do
  @behaviour MyApp.API.RPCBehaviour

  @moduledoc """
  Provides inter-node communication utilities using Elixir's `:rpc` module.

  Note:
  - `call_remote/4` performs a synchronous call and returns {:ok, result} or {:error, reason}.
  - `cast_remote/4` attempts to mimic a cast-like call, but still detects errors by using `:rpc.call`.
    If the function doesn't exist, it will return {:error, reason} rather than just :ok.
  """

  @doc """
  Makes a synchronous call to a remote node.

  ## Parameters
  - `node`: The target node to call.
  - `module`: The module to invoke on the target node.
  - `function`: The function to invoke on the target module.
  - `args`: A list of arguments to pass to the function.

  ## Returns
  - `{:ok, result}` if the remote function call is successful.
  - `{:error, reason}` if the remote function call fails.

  ## Examples

      iex> MyApp.API.RPC.call_remote(:'node1@localhost', MyApp.Storage.StoreServer, :get, ["key"])
      {:ok, "value"}

      iex> MyApp.API.RPC.call_remote(:'node1@localhost', NonExistentModule, :non_existent_func, [])
      {:error, {:EXIT, {:undef, ...}}}
  """
  def call_remote(node, module, function, args) do
    case :rpc.call(node, module, function, args) do
      {:badrpc, reason} ->
        {:error, reason}

      result ->
        {:ok, result}
    end
  end


  @doc """
  Makes a call that is intended to behave like a cast, but still returns errors if the remote function doesn't exist.

  While a true `:rpc.cast` does not return errors, this function uses `:rpc.call` underneath to
  check for errors and then simply returns `:ok` if the function exists and runs without error.

  ## Parameters
  - `node`: The target node to call.
  - `module`: The module to invoke on the target node.
  - `function`: The function to invoke on the target module.
  - `args`: A list of arguments to pass to the function.

  ## Returns
  - `:ok` if the remote function is invoked successfully.
  - `{:error, reason}` if the remote function call fails (e.g., function not defined).

  ## Examples

      iex> MyApp.API.RPC.cast_remote(:'node1@localhost', MyApp.Storage.StoreServer, :put, ["key", "value"])
      :ok

      iex> MyApp.API.RPC.cast_remote(:'node1@localhost', NonExistentModule, :non_existent_func, [])
      {:error, {:EXIT, {:undef, ...}}}
  """

  def cast_remote(node, module, function, args) do
    case :rpc.call(node, module, function, args) do
      {:badrpc, reason} ->
        {:error, reason}

      _ ->
        :ok
    end
  end
end
