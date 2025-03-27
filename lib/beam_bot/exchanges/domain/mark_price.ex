defmodule BeamBot.Exchanges.Domain.MarkPriceUpdate do
  @moduledoc """
  Domain model for mark price updates from various exchanges.
  Contains structures and functions for working with mark price data.
  """

  @type t :: %__MODULE__{
          exchange: String.t(),
          symbol: String.t(),
          event_time: DateTime.t(),
          mark_price: Decimal.t(),
          index_price: Decimal.t(),
          estimated_settlement_price: Decimal.t(),
          funding_rate: Decimal.t(),
          next_funding_time: DateTime.t()
        }

  defstruct [
    :exchange,
    :symbol,
    :event_time,
    :mark_price,
    :index_price,
    :estimated_settlement_price,
    :funding_rate,
    :next_funding_time
  ]

  @doc """
  Creates a new mark price update from Binance WebSocket data.

  ## Examples

      iex> data = %{"E" => 1743112926001, "P" => "87598.14166728", "T" => 1743120000000, "e" => "markPriceUpdate", "i" => "87588.32755556", "p" => "87559.90000000", "r" => "0.00000536", "s" => "BTCUSDT"}
      iex> BeamBot.Exchanges.Domain.MarkPriceUpdate.from_binance(data)
      %BeamBot.Exchanges.Domain.MarkPriceUpdate{
        exchange: "binance",
        symbol: "BTCUSDT",
        event_time: DateTime.from_unix!(1743112926001, :millisecond),
        mark_price: Decimal.new("87559.90000000"),
        index_price: Decimal.new("87588.32755556"),
        estimated_settlement_price: Decimal.new("87598.14166728"),
        funding_rate: Decimal.new("0.00000536"),
        next_funding_time: DateTime.from_unix!(1743120000000, :millisecond)
      }
  """
  def from_binance(data) do
    event_time =
      data["E"]
      |> DateTime.from_unix!(:millisecond)

    next_funding_time =
      data["T"]
      |> DateTime.from_unix!(:millisecond)

    mark_price = Decimal.new(data["p"])
    index_price = Decimal.new(data["i"])
    estimated_settlement_price = Decimal.new(data["P"])
    funding_rate = Decimal.new(data["r"])

    %__MODULE__{
      exchange: "binance",
      symbol: data["s"],
      event_time: event_time,
      mark_price: mark_price,
      index_price: index_price,
      estimated_settlement_price: estimated_settlement_price,
      funding_rate: funding_rate,
      next_funding_time: next_funding_time
    }
  end
end
