# lib/my_app/distribution/node_responsibility_manager_behaviour.ex
defmodule MyApp.Distribution.NodeResponsibilityManagerBehaviour do
  @callback get_node_for_key(any()) ::
              {:ok, node()} | {:error, any()}
end