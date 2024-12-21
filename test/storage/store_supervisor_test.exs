defmodule MyApp.Storage.StoreSupervisorTest do
  use ExUnit.Case, async: true

  alias MyApp.Storage.{StoreSupervisor, StoreServer}

  setup do
    # Start the StoreSupervisor with a unique name for each test
    unique_name = :"store_supervisor_#{:erlang.unique_integer([:positive])}"
    {:ok, supervisor} = StoreSupervisor.start_link(name: unique_name)
    %{supervisor: supervisor}
  end

  test "starts StoreSupervisor successfully", %{supervisor: supervisor} do
    assert Process.alive?(supervisor)
  end

  test "can dynamically start a StoreServer", %{supervisor: _supervisor} do
    partition_id = :partition_1

    # Start a StoreServer dynamically
    assert {:ok, pid} = StoreSupervisor.start_store_server(partition_id)
    assert Process.alive?(pid)

    # Verify the StoreServer is managing the correct partition
    assert GenServer.call(pid, :get_partition_id) == partition_id
  end

  test "can stop a StoreServer dynamically", %{supervisor: _supervisor} do
    partition_id = :partition_2

    # Start a StoreServer dynamically
    assert {:ok, pid} = StoreSupervisor.start_store_server(partition_id)
    assert Process.alive?(pid)

    # Stop the StoreServer
    assert :ok = StoreSupervisor.stop_store_server(pid)
    refute Process.alive?(pid)
  end

  test "handles stopping a non-existent StoreServer", %{supervisor: _supervisor} do
    non_existent_pid = self() # Use the test process PID as a dummy

    assert {:error, :not_found} = StoreSupervisor.stop_store_server(non_existent_pid)
  end
end
