defmodule Emcd do
  @moduledoc """
  Module for connection to memcached server using text protocol.

  ## Example

    {:ok, ["STORED"]} = Emcd.set("key", "value")
    {:ok, ["VALUE key 0 1", "value", "END"]} = Emcd.get("key")

  """
  use Application
  require Logger

  @default_host "127.0.0.1"
  @default_port 3000
  @default_timeout 5000
  @default_namespace nil

  @doc """
  Starts application.
  """
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    connection_options = [:list, active: false, packet: :raw]

    worker_options = [
      host: Application.get_env(:emcd, :host, @default_host) |> String.to_charlist(),
      port: Application.get_env(:emcd, :port, @default_port),
      timeout: Application.get_env(:emcd, :timeout, @default_timeout),
      namespace: Application.get_env(:emcd, :namespace, @default_namespace),
      connection_options: connection_options
    ]

    children = [worker(Emcd.Worker, [worker_options])]

    Supervisor.start_link(children, [strategy: :one_for_one, name: Emcd.Supervisor])
  end

  def get(key) do
    case GenServer.call(Emcd.Worker, {:get, key}) do
      {:ok, [_, payload, _]} ->
        output = trim_leading(payload, 194)
        {:ok, :erlang.binary_to_term(output)}
      _ ->
        {:error}
    end
  end

  def set(key, value, exptime \\ 3600) do
    output = :erlang.term_to_binary(value)
    GenServer.call(Emcd.Worker, {:set, key, output, exptime})
  end

  def delete(key) do
    GenServer.call(Emcd.Worker, {:delete, key})
  end

  def version() do
    GenServer.call(Emcd.Worker, {:version})
  end

  def retry(interval) do
    Logger.info "Retrying to connect to server in #{interval / 1_000} seconds"
    :timer.sleep(interval)
    GenServer.cast(Emcd.Worker, {:connect, interval})
  end

  defp trim_leading(binary, byte \\ 0)
  defp trim_leading(<< byte, binary :: binary >>, byte) when is_binary(binary) and is_integer(byte), do: trim_leading(binary, byte)
  defp trim_leading(binary, byte) when is_binary(binary) and is_integer(byte), do: binary
end
