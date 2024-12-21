# lib/my_app/api/rpc_behaviour.ex
defmodule MyApp.API.RPCBehaviour do
  @callback call_remote(node(), module(), atom(), list()) ::
              {:ok, any()} | {:error, any()}

  @callback cast_remote(node(), module(), atom(), list()) ::
              :ok | {:error, any()}
end