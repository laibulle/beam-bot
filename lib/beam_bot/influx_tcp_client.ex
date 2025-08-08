defmodule BeamBot.InfluxTCPClient do
  @moduledoc """
  Sends Influx Line Protocol data to QuestDB via TCP.
  """

  require Logger

  def get_port do
    Application.get_env(:beam_bot, :questdb_tcp_port)
  end

  def get_host do
    to_charlist(Application.get_env(:beam_bot, :questdb_host))
  end

  @doc """
  LogSends a line of Influx Line Protocol data to QuestDB via TCP.

  BeamBot.InfluxTCPClient.send_line("weather,location=us-midwest temperature=82 1465839830100400200")

  """
  def send_line(line_protocol_string) when is_binary(line_protocol_string) do
    :gen_tcp.connect(get_host(), get_port(), [:binary, packet: :raw, active: false])
    |> case do
      {:ok, socket} ->
        case :gen_tcp.send(socket, line_protocol_string <> "\n") do
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
end
