defmodule MyApp.Storage.StoreSupervisor do
  use Supervisor
  require Logger

  @moduledoc """
  Supervisor for managing multiple StoreServer processes.

  Responsibilities:
  - Starts and supervises StoreServer processes.
  - Dynamically starts new StoreServer instances as needed.
  """

  # Public API

  @doc """
  Starts the StoreSupervisor.

  ## Parameters
  - `opts`: Options passed to the Supervisor.

  ## Returns
  - `{:ok, pid}`: If the supervisor starts successfully.
  """
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Starts a new StoreServer process dynamically.

  ## Parameters
  - `partition_id`: An identifier for the partition this StoreServer will manage.

  ## Returns
  - `{:ok, pid}`: The PID of the started StoreServer process.
  - `{:error, reason}`: If the process could not be started.
  """
  def start_store_server(partition_id) do

    case DynamicSupervisor.start_child(
           __MODULE__,
           %{
             id: {:store_server, partition_id},
             start: {
               MyApp.Storage.StoreServer,
               :start_link,
               [partition_id, []]
             },
             restart: :permanent,
             type: :worker
           }
         ) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Stops a StoreServer process dynamically.

  ## Parameters
  - `pid`: The PID of the StoreServer process to stop.

  ## Returns
  - `:ok`: If the process was stopped successfully.
  - `{:error, reason}`: If the process could not be stopped.
  """
  def stop_store_server(pid) do

    case DynamicSupervisor.terminate_child(__MODULE__, pid) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Supervisor Callbacks

  @impl true
  def init(:ok) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: __MODULE__}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
