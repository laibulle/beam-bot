defmodule BeamBot.Exchanges.Domain.Kline do
  @moduledoc """
  Schema for storing klines data in TimescaleDB.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "klines" do
    field :symbol, :string, primary_key: true
    field :interval, :string, primary_key: true
    field :timestamp, :integer, primary_key: true
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
