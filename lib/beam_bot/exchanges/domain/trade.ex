defmodule BeamBot.Exchanges.Domain.Trade do
  @moduledoc """
  Domain model for trades from various exchanges.
  Contains structures and functions for working with trade data.
  """

  @type t :: %__MODULE__.AggregateTrade{}

  @doc """
  Extract symbol from a Binance WebSocket stream name

  ## Examples

      iex> BeamBot.Exchanges.Domain.Trade.extract_symbol_from_stream("binance:btcusdt@aggTrade")
      "BTCUSDT"

      iex> BeamBot.Exchanges.Domain.Trade.extract_symbol_from_stream("binance:ethusdt@kline_1m")
      "ETHUSDT"
  """
  def extract_symbol_from_stream("binance:" <> rest) do
    case String.split(rest, "@", parts: 2) do
      [symbol, _] -> String.upcase(symbol)
      _ -> nil
    end
  end

  def extract_symbol_from_stream(_), do: nil

  defmodule AggregateTrade do
    @moduledoc """
    Represents an aggregate trade from an exchange.
    An aggregate trade combines multiple trades at the same price level within a short time window.
    """

    @type t :: %__MODULE__{
            exchange: String.t(),
            symbol: String.t(),
            price: Decimal.t(),
            quantity: Decimal.t(),
            trade_value: Decimal.t(),
            trade_type: :buy | :sell,
            trade_time: DateTime.t(),
            event_time: DateTime.t(),
            aggregate_trade_id: pos_integer(),
            first_trade_id: pos_integer(),
            last_trade_id: pos_integer(),
            was_market_maker: boolean()
          }

    defstruct [
      :exchange,
      :symbol,
      :price,
      :quantity,
      :trade_value,
      :trade_type,
      :trade_time,
      :event_time,
      :aggregate_trade_id,
      :first_trade_id,
      :last_trade_id,
      :was_market_maker
    ]

    @doc """
    Creates a new aggregate trade from Binance WebSocket data.

    ## Examples

        iex> data = %{"E" => 1743111789577, "T" => 1743111789511, "a" => 2649000004, "e" => "aggTrade", "f" => 6140156480, "l" => 6140156503, "m" => true, "p" => "87605.20", "q" => "0.276", "s" => "BTCUSDT"}
        iex> BeamBot.Exchanges.Domain.Trade.AggregateTrade.from_binance(data)
        %BeamBot.Exchanges.Domain.Trade.AggregateTrade{
          exchange: "binance",
          symbol: "BTCUSDT",
          price: Decimal.new("87605.20"),
          quantity: Decimal.new("0.276"),
          trade_value: Decimal.mult(Decimal.new("87605.20"), Decimal.new("0.276")),
          trade_type: :sell,
          trade_time: DateTime.from_unix!(1743111789511, :millisecond),
          event_time: DateTime.from_unix!(1743111789577, :millisecond),
          aggregate_trade_id: 2649000004,
          first_trade_id: 6140156480,
          last_trade_id: 6140156503,
          was_market_maker: true
        }
    """
    def from_binance(data) do
      trade_time =
        data["T"]
        |> DateTime.from_unix!(:millisecond)

      event_time =
        data["E"]
        |> DateTime.from_unix!(:millisecond)

      price =
        data["p"]
        |> Decimal.new()

      quantity =
        data["q"]
        |> Decimal.new()

      trade_value = Decimal.mult(price, quantity)

      trade_type = if data["m"], do: :sell, else: :buy

      %__MODULE__{
        exchange: "binance",
        symbol: data["s"],
        price: price,
        quantity: quantity,
        trade_value: trade_value,
        trade_type: trade_type,
        trade_time: trade_time,
        event_time: event_time,
        aggregate_trade_id: data["a"],
        first_trade_id: data["f"],
        last_trade_id: data["l"],
        was_market_maker: data["m"]
      }
    end
  end
end
