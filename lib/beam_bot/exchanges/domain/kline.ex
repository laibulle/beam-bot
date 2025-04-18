defmodule BeamBot.Exchanges.Domain.Kline do
  @moduledoc """
  Domain model for klines (candlestick data) from various exchanges.
  Contains structures and functions for working with kline data.
  """

  use Ecto.Schema
  @primary_key false
  import Ecto.Changeset

  @type t :: %__MODULE__{
          symbol: String.t(),
          platform: String.t(),
          interval: String.t(),
          timestamp: DateTime.t(),
          open: Decimal.t(),
          high: Decimal.t(),
          low: Decimal.t(),
          close: Decimal.t(),
          volume: Decimal.t(),
          quote_volume: Decimal.t() | nil,
          trades_count: integer() | nil,
          taker_buy_base_volume: Decimal.t() | nil,
          taker_buy_quote_volume: Decimal.t() | nil,
          ignore: Decimal.t() | nil
        }

  @type kline_tuple :: {
          String.t(),
          String.t(),
          String.t(),
          DateTime.t(),
          Decimal.t(),
          Decimal.t(),
          Decimal.t(),
          Decimal.t(),
          Decimal.t(),
          Decimal.t() | nil,
          integer() | nil,
          Decimal.t() | nil,
          Decimal.t() | nil,
          Decimal.t() | nil
        }

  @derive {Jason.Encoder,
           only: [
             :symbol,
             :platform,
             :interval,
             :timestamp,
             :open,
             :high,
             :low,
             :close,
             :volume,
             :quote_volume,
             :trades_count,
             :taker_buy_base_volume,
             :taker_buy_quote_volume,
             :ignore
           ]}
  schema "klines" do
    field :symbol, :string
    field :platform, :string
    field :interval, :string
    field :timestamp, :utc_datetime
    field :open, :decimal
    field :high, :decimal
    field :low, :decimal
    field :close, :decimal
    field :volume, :decimal
    field :quote_volume, :decimal
    field :trades_count, :integer
    field :taker_buy_base_volume, :decimal
    field :taker_buy_quote_volume, :decimal
    field :ignore, :decimal
  end

  @doc false
  def changeset(kline, attrs) do
    kline
    |> cast(attrs, [
      :symbol,
      :platform,
      :interval,
      :timestamp,
      :open,
      :high,
      :low,
      :close,
      :volume,
      :quote_volume,
      :trades_count,
      :taker_buy_base_volume,
      :taker_buy_quote_volume,
      :ignore
    ])
    |> validate_required([
      :symbol,
      :platform,
      :interval,
      :timestamp,
      :open,
      :high,
      :low,
      :close,
      :volume
    ])
  end

  @spec to_tuple(t()) :: kline_tuple()
  def to_tuple(%__MODULE__{} = kline) do
    {
      kline.symbol,
      kline.platform,
      kline.interval,
      kline.timestamp,
      kline.open,
      kline.high,
      kline.low,
      kline.close,
      kline.volume,
      kline.quote_volume,
      kline.trades_count,
      kline.taker_buy_base_volume,
      kline.taker_buy_quote_volume,
      kline.ignore
    }
  end

  @doc """
  Converts a Kline struct directly to a tuple for improved memory efficiency.
  This function avoids any intermediate steps and directly returns the tuple representation.
  """
  @spec kline_to_tuple(t()) :: kline_tuple()
  def kline_to_tuple(%__MODULE__{
        symbol: symbol,
        platform: platform,
        interval: interval,
        timestamp: timestamp,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
        quote_volume: quote_volume,
        trades_count: trades_count,
        taker_buy_base_volume: taker_buy_base_volume,
        taker_buy_quote_volume: taker_buy_quote_volume,
        ignore: ignore
      }) do
    {
      symbol,
      platform,
      interval,
      timestamp,
      open,
      high,
      low,
      close,
      volume,
      quote_volume,
      trades_count,
      taker_buy_base_volume,
      taker_buy_quote_volume,
      ignore
    }
  end

  @doc """
  Converts a kline tuple back into a Kline struct.
  This is the inverse operation of kline_to_tuple/1.
  """
  @spec tuple_to_kline(kline_tuple()) :: t()
  def tuple_to_kline({
        symbol,
        platform,
        interval,
        timestamp,
        open,
        high,
        low,
        close,
        volume,
        quote_volume,
        trades_count,
        taker_buy_base_volume,
        taker_buy_quote_volume,
        ignore
      }) do
    %__MODULE__{
      symbol: symbol,
      platform: platform,
      interval: interval,
      timestamp: timestamp,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
      quote_volume: quote_volume,
      trades_count: trades_count,
      taker_buy_base_volume: taker_buy_base_volume,
      taker_buy_quote_volume: taker_buy_quote_volume,
      ignore: ignore
    }
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
