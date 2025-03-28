defmodule BeamBot.Exchanges.Domain.Kline do
  @moduledoc """
  Domain model for klines (candlestick data) from various exchanges.
  Contains structures and functions for working with kline data.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          symbol: String.t(),
          interval: String.t(),
          timestamp: integer(),
          open: float(),
          high: float(),
          low: float(),
          close: float(),
          volume: float(),
          close_time: integer() | nil,
          quote_volume: float() | nil,
          trades_count: integer() | nil,
          taker_buy_base_volume: float() | nil,
          taker_buy_quote_volume: float() | nil,
          ignore: float() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "klines" do
    field :symbol, :string
    field :interval, :string
    field :timestamp, :integer
    field :open, :float
    field :high, :float
    field :low, :float
    field :close, :float
    field :volume, :float
    field :close_time, :integer
    field :quote_volume, :float
    field :trades_count, :integer
    field :taker_buy_base_volume, :float
    field :taker_buy_quote_volume, :float
    field :ignore, :float

    timestamps()
  end

  @doc false
  def changeset(kline, attrs) do
    kline
    |> cast(attrs, [
      :symbol,
      :interval,
      :timestamp,
      :open,
      :high,
      :low,
      :close,
      :volume,
      :close_time,
      :quote_volume,
      :trades_count,
      :taker_buy_base_volume,
      :taker_buy_quote_volume,
      :ignore
    ])
    |> validate_required([
      :symbol,
      :interval,
      :timestamp,
      :open,
      :high,
      :low,
      :close,
      :volume
    ])
  end
end

defimpl Enumerable, for: BeamBot.Exchanges.Domain.Kline do
  def count(_kline), do: {:ok, 1}
  def member?(_kline, _value), do: {:ok, false}
  def slice(_kline), do: {:ok, 1, fn _ -> [] end}
  def reduce(_kline, {:halt, acc}, _fun), do: {:halted, acc}
  def reduce(_kline, {:suspend, acc}, _fun), do: {:suspended, acc}
  def reduce(kline, {:cont, acc}, fun), do: {:done, fun.(Map.from_struct(kline), acc)}
end
