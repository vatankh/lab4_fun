defmodule MyApp.API.RequestHandler do
  @moduledoc """
  Handles incoming requests to the distributed key-value store and delegates
  them to the appropriate functions in the `Client` module.

  This module is designed to work with external communication protocols (e.g., HTTP, TCP).
  It parses incoming requests, delegates to `MyApp.API.Client`, and returns appropriate responses.
  """

  alias MyApp.API.Client

  @doc """
  Starts the RequestHandler server.

  ## Options
  - `:port` (default: 4000): The port to listen on for incoming requests.

  ## Example

      MyApp.API.RequestHandler.start_link(port: 4000)
  """
  def start_link(opts) do
    port = Keyword.get(opts, :port, 4000)
    Task.start_link(fn -> listen(port) end)
  end

  @doc """
  Defines the child_spec function for RequestHandler, so it can be used in a supervision tree.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc """
  Parses and handles an incoming request.

  Expected format:
  - `{operation, key, value}` tuple for operations like `put`
  - `{operation, key}` tuple for `get` and `delete`

  Returns a response tuple or an error.
  """
  def handle_request({:get, key}) do
    case Client.get(key) do
      {:ok, value} ->
        {:ok, value}
      :not_found ->
        {:error, :not_found}
    end
  end

  def handle_request({:put, key, value}) do
    case Client.put(key, value) do
      :ok ->
        {:ok, :put_success}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_request({:delete, key}) do
    case Client.delete(key) do
      :ok ->
        {:ok, :delete_success}
      :not_found ->
        {:error, :not_found}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def handle_request(invalid_request) do
    {:error, :invalid_request}
  end

  # Internal: Starts listening for incoming requests.
  defp listen(port) do
    case :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true]) do
      {:ok, socket} ->
        loop_accept(socket)

      {:error, :eaddrinuse} ->
        {:ok, socket} = :gen_tcp.listen(0, [:binary, packet: :line, active: false, reuseaddr: true])
        {:ok, assigned_port} = :inet.port(socket)
        Application.put_env(:my_app, :assigned_port, assigned_port)
        loop_accept(socket)
    end
  end

  # Internal: Accept incoming connections.
  defp loop_accept(socket) do
    case :gen_tcp.accept(socket) do
      {:ok, client} ->
        Task.start(fn -> handle_client(client) end)
        loop_accept(socket)

      {:error, _reason} ->
        :ok
    end
  end

  # Internal: Handle the client connection.
  defp handle_client(socket) do
    loop_receive(socket)
  end

  defp loop_receive(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, request} ->
        response =
          case parse_request(request) do
            {:ok, parsed_request} ->
              handle_request(parsed_request)

            {:error, _reason} ->
              {:error, :invalid_request_format}
          end

        send_response(socket, response)
        loop_receive(socket)

      {:error, _reason} ->
        :ok
    end
  end

  # Internal: Parses a raw request into an actionable format.
  def parse_request(raw_request) do
    case String.trim(raw_request) |> Jason.decode() do
      {:ok, %{"operation" => "get", "key" => key}} ->
        {:ok, {:get, key}}

      {:ok, %{"operation" => "delete", "key" => key}} ->
        {:ok, {:delete, key}}

      {:ok, %{"operation" => "put", "key" => key, "value" => value}} ->
        {:ok, {:put, key, value}}

      _ ->
        {:error, :invalid_request_format}
    end
  end

  defp send_response(socket, {:ok, value}) do
    encoded_response = Jason.encode!(%{"ok" => value})
    :gen_tcp.send(socket, encoded_response <> "\n")
  end
  defp send_response(socket, {:error, reason}) do
    encoded_response = Jason.encode!(%{"error" => reason})
    :gen_tcp.send(socket, encoded_response <> "\n")
  end
end
