defmodule MyApp.Application do
  @moduledoc """
  The entry point for the MyApp application. This module defines the supervision
  tree and starts all other components as children under a main supervisor.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [

      # 1) Start the local StoreSupervisor (manages StoreServer processes)
      MyApp.Storage.StoreSupervisor,

      # 2) Start the cluster MembershipManager
      MyApp.Cluster.MembershipManager,

      # 3) Start the GossipProtocol for cluster synchronization
      MyApp.Cluster.GossipProtocol,

      # 4) Start the NodeResponsibilityManager (depends on MembershipManager + ConsistentHashRing)
      MyApp.Distribution.NodeResponsibilityManager,

      # 5) Start the RequestHandler for external requests (API layer)
      MyApp.API.RequestHandler
    ]

    # The top-level supervisor for your application.
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
