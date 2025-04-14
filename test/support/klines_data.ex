defmodule BeamBotWeb.KlinesData do
  @moduledoc false

  defmodule InputSettings do
    @moduledoc false
    defstruct [
      :interval,
      :start_time,
      :end_time
    ]
  end

  defp get_klines_count(%InputSettings{
         interval: interval,
         start_time: start_time,
         end_time: end_time
       }) do
    # Convert interval to seconds (e.g., "1h" -> 3600, "4h" -> 14400)
    interval_in_seconds =
      case interval do
        "1h" -> 3600
        "4h" -> 14_400
        _ -> raise "Unsupported interval"
      end

    # Calculate the total number of intervals between start_time and end_time
    div(DateTime.diff(end_time, start_time, :second), interval_in_seconds)
  end

  def generate_klines_data(
        %InputSettings{
          interval: interval,
          start_time: start_time,
          end_time: _end_time
        } = input
      ) do
    interval_in_seconds =
      case interval do
        "1h" -> 3600
        "4h" -> 14_400
        _ -> raise "Unsupported interval"
      end

    klines_count = get_klines_count(input)

    Enum.map(0..(klines_count - 1), fn i ->
      open_time = DateTime.add(start_time, i * interval_in_seconds, :second)
      close_time = DateTime.add(open_time, interval_in_seconds, :second)

      [
        # Open price
        0.0163479 + i * 0.0001,
        # High price
        0.8 + i * 0.0001,
        # Low price
        0.015758 + i * 0.0001,
        # Close price
        0.015771 + i * 0.0001,
        # Volume
        148_976.11427815 + i * 100,
        # Close time (timestamp)
        DateTime.to_unix(close_time, :millisecond),
        # Quote asset volume
        2434.19055334 + i * 10,
        # Number of trades
        308 + i,
        # Taker buy base asset volume
        1756.87402397 + i * 5,
        # Taker buy quote asset volume
        28.46694368 + i * 0.1,
        # Open time (ISO 8601 format)
        DateTime.to_iso8601(open_time)
      ]
    end)
  end
end
