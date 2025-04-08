defmodule BeamBot.InfluxTCPClient do
  @moduledoc """
  Sends Influx Line Protocol data to QuestDB via TCP.
  """

  @host ~c"localhost"
  @port 9009

  require Logger

  @doc """
  Sends a line of Influx Line Protocol data to QuestDB via TCP.


  ## Example
  iex> BeamBot.InfluxTCPClient.send_line(lines = [
  "metrics,host=server01 cpu=0.65 1640995200000000000",
  "metrics,host=server02 cpu=0.70 1640995200001000000"
  ] |> Enum.join("\n"))
  """
  def send_line(line_protocol_string) when is_binary(line_protocol_string) do
    :gen_tcp.connect(@host, @port, [:binary, packet: :raw, active: false])
    |> case do
      {:ok, socket} ->
        case :gen_tcp.send(socket, line_protocol_string) do
          :ok ->
            :gen_tcp.close(socket)
            :ok

          {:error, send_reason} ->
            :gen_tcp.close(socket)

            Logger.error(
              "Failed to send data to QuestDB: #{inspect(send_reason)}, data: #{String.slice(line_protocol_string, 0, 100)}..."
            )

            {:error, send_reason}
        end

      {:error, reason} ->
        Logger.error("Failed to connect to QuestDB: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Sends a line of Influx Line Protocol data to QuestDB via TCP,
  but silently handles parse errors on the QuestDB side.

  This is useful when you know the data might contain format issues
  but you want the application to continue running.
  """
  def send_line_ignore_parse_errors(line_protocol_string) when is_binary(line_protocol_string) do
    result = send_line(line_protocol_string)

    case result do
      :ok ->
        :ok

      {:error, _reason} ->
        Logger.error(
          "Ignoring QuestDB parse error for data: #{String.slice(line_protocol_string, 0, 100)}..."
        )

        :ok_with_errors
    end
  end
end
