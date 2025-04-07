defmodule BeamBot.Exchanges.Domain.TradingPair do
  @moduledoc """
  This module is responsible for managing the trading pairs.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias BeamBot.Exchanges.Domain.Exchange

  @type t :: %__MODULE__{
          id: integer() | nil,
          exchange_id: integer() | nil,
          exchange: Exchange.t() | nil,
          symbol: String.t() | nil,
          base_asset: String.t() | nil,
          quote_asset: String.t() | nil,
          min_price: Decimal.t() | nil,
          max_price: Decimal.t() | nil,
          tick_size: Decimal.t() | nil,
          min_qty: Decimal.t() | nil,
          max_qty: Decimal.t() | nil,
          step_size: Decimal.t() | nil,
          min_notional: Decimal.t() | nil,
          is_active: boolean(),
          status: String.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @derive {Jason.Encoder,
           only: [
             :symbol,
             :base_asset,
             :quote_asset,
             :min_price,
             :max_price,
             :tick_size,
             :min_qty,
             :max_qty,
             :step_size,
             :min_notional,
             :is_active,
             :status
           ]}
  schema "trading_pairs" do
    belongs_to :exchange, Exchange
    field :symbol, :string
    field :base_asset, :string
    field :quote_asset, :string
    field :status, :string
    field :min_price, :decimal
    field :max_price, :decimal
    field :tick_size, :decimal
    field :min_qty, :decimal
    field :max_qty, :decimal
    field :step_size, :decimal
    field :min_notional, :decimal
    field :is_active, :boolean, default: true

    timestamps()
  end

  @doc false
  def changeset(trading_pair, attrs) do
    trading_pair
    |> cast(attrs, [
      :exchange_id,
      :symbol,
      :base_asset,
      :quote_asset,
      :min_price,
      :max_price,
      :tick_size,
      :min_qty,
      :max_qty,
      :step_size,
      :min_notional,
      :is_active,
      :status
    ])
    |> validate_required([
      :exchange_id,
      :symbol,
      :base_asset,
      :quote_asset,
      :status
    ])
    |> foreign_key_constraint(:exchange_id)
  end
end
