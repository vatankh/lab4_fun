defmodule MyApp.API.RequestHandlerTest do
  use ExUnit.Case
  require Logger
  alias MyApp.API.RequestHandler

  import Mox
  import ExUnit.CaptureLog

  # Enable Mox globally for tests
  setup :verify_on_exit!

  setup do
    Application.put_env(:my_app, :node_responsibility_manager, MyApp.Distribution.NodeResponsibilityManagerMock)
    Application.put_env(:my_app, :rpc_module, MyApp.API.RPCMock)

    MyApp.Distribution.NodeResponsibilityManagerMock
    |> Mox.stub(:get_node_for_key, fn _key -> {:ok, :node_name} end)

    MyApp.API.RPCMock
    |> Mox.stub(:call_remote, fn _node, _module, _function, _args -> {:ok, :mocked_response} end)
    |> Mox.stub(:cast_remote, fn _node, _module, _function, _args -> :ok end)

    :ok
  end
  # Define mock for ClientBehaviour

  describe "handle_request/1" do
    test "handles a get request successfully" do
      MyApp.API.RPCMock
      |> expect(:call_remote, fn _node, _module, :get, ["test_key"] -> {:ok, "test_value"} end)

      assert RequestHandler.handle_request({:get, "test_key"}) == {:ok, "test_value"}
    end

    test "handles a get request for a non-existent key" do
      MyApp.API.RPCMock
      |> expect(:call_remote, fn _node, _module, :get, ["missing_key"] -> :not_found end)

      assert RequestHandler.handle_request({:get, "missing_key"}) == {:error, :not_found}
    end

    test "handles a put request successfully" do
      MyApp.API.RPCMock
      |> expect(:cast_remote, fn _node, MyApp.Storage.StoreServer, :put, ["test_key", "test_value"] -> :ok end)

      assert RequestHandler.handle_request({:put, "test_key", "test_value"}) == {:ok, :put_success}

    end

    test "handles a delete request successfully" do
      MyApp.API.RPCMock
      |> expect(:call_remote, fn _node, MyApp.Storage.StoreServer, :delete, ["test_key"] -> :ok end)

      assert RequestHandler.handle_request({:delete, "test_key"}) == {:ok, :delete_success}

    end

    test "handles a delete request for a non-existent key" do
      MyApp.API.RPCMock
      |> expect(:call_remote, fn _node, MyApp.Storage.StoreServer, :delete, ["missing_key"] -> :not_found end)

      assert RequestHandler.handle_request({:delete, "missing_key"}) == {:error, :not_found}
    end

    test "returns an error for invalid request formats" do
      assert RequestHandler.handle_request(:invalid_request) == {:error, :invalid_request}
    end
  end

  describe "parse_request/1" do
    test "parses a valid get request" do
      raw_request = Jason.encode!(%{"operation" => "get", "key" => "test_key"})
      assert RequestHandler.parse_request(raw_request) == {:ok, {:get, "test_key"}}
    end

    test "parses a valid put request" do
      raw_request = Jason.encode!(%{"operation" => "put", "key" => "test_key", "value" => "test_value"})
      assert RequestHandler.parse_request(raw_request) == {:ok, {:put, "test_key", "test_value"}}
    end

    test "parses a valid delete request" do
      raw_request = Jason.encode!(%{"operation" => "delete", "key" => "test_key"})
      assert RequestHandler.parse_request(raw_request) == {:ok, {:delete, "test_key"}}
    end

    test "returns an error for an invalid request format" do
      raw_request = "invalid json"
      assert RequestHandler.parse_request(raw_request) == {:error, :invalid_request_format}
    end

    test "returns an error for a request with missing fields" do
      raw_request = Jason.encode!(%{"operation" => "put", "key" => "test_key"})
      assert RequestHandler.parse_request(raw_request) == {:error, :invalid_request_format}
    end
  end

  describe "integration tests" do
    test "logs and handles a valid request" do
      Logger.info("Test: Starting RequestHandler...")
      port = 4040
      {:ok, _pid} = Task.start(fn -> MyApp.API.RequestHandler.start_link(port: port) end)
      :timer.sleep(500)  # Allow the server to start
      Logger.info("Test: RequestHandler started successfully")

      MyApp.API.RPCMock
      |> expect(:call_remote, fn _node, _module, :get, ["test_key"] -> {:ok, "test_value"} end)
      Logger.info("Test: RPCMock setup successfully")
      raw_request = Jason.encode!(%{"operation" => "get", "key" => "test_key"})
      Logger.info("Test: Sending raw request: #{raw_request}")
      {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, packet: :line, active: false])
         Logger.info("Test: Socket connected")

        :ok = :gen_tcp.send(socket, raw_request <> "\n")
        Logger.info("Test: Request sent successfully")

        case :gen_tcp.recv(socket, 0, 5000) do
          {:ok, response} ->
            Logger.info("Test: Received response: #{response}")
            assert Jason.decode!(response) == %{"ok" => "test_value"}
          {:error, reason} ->
            Logger.error("Test: Error receiving response: #{inspect(reason)}")
            flunk("Test: Unexpected error: #{inspect(reason)}")
        end
    end
  end


end
