defmodule MyApp.API.ClientBehaviour do
  @callback get(String.t()) :: {:ok, any()} | :not_found
  @callback put(String.t(), any()) :: :ok | {:error, term()}
  @callback delete(String.t()) :: :ok | {:error, term()} | :not_found
end
