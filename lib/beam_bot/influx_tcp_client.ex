defmodule BeamBot.InfluxTCPClient do
  @moduledoc """
  Sends Influx Line Protocol data to QuestDB via TCP.
  """

  @host ~c"localhost"
  @port 9009

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
        :gen_tcp.send(socket, line_protocol_string)
        :gen_tcp.close(socket)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
