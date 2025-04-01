defmodule BeamBot.Strategies.Domain.Strategy do
  @moduledoc """
  Schema for storing trading strategies in the database.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "strategies" do
    field :trading_pair, :string
    field :timeframe, :string
    field :investment_amount, :decimal
    field :max_risk_percentage, :decimal
    field :rsi_oversold_threshold, :integer
    field :rsi_overbought_threshold, :integer
    field :ma_short_period, :integer
    field :ma_long_period, :integer
    # :active, :paused, :stopped
    field :status, :string
    field :activated_at, :utc_datetime
    field :last_execution_at, :utc_datetime
    field :maker_fee, :decimal
    field :taker_fee, :decimal

    timestamps()
  end

  @doc """
  Creates a changeset for the strategy.
  """
  def changeset(strategy, attrs) do
    strategy
    |> cast(attrs, [
      :trading_pair,
      :timeframe,
      :investment_amount,
      :max_risk_percentage,
      :rsi_oversold_threshold,
      :rsi_overbought_threshold,
      :ma_short_period,
      :ma_long_period,
      :status,
      :activated_at,
      :last_execution_at,
      :maker_fee,
      :taker_fee
    ])
    |> validate_required([
      :trading_pair,
      :timeframe,
      :investment_amount,
      :max_risk_percentage,
      :rsi_oversold_threshold,
      :rsi_overbought_threshold,
      :ma_short_period,
      :ma_long_period,
      :status,
      :activated_at,
      :maker_fee,
      :taker_fee
    ])
    |> validate_inclusion(:status, ["active", "paused", "stopped"])
    |> validate_number(:max_risk_percentage, greater_than: 0, less_than: 100)
    |> validate_number(:rsi_oversold_threshold, greater_than: 0, less_than: 100)
    |> validate_number(:rsi_overbought_threshold, greater_than: 0, less_than: 100)
    |> validate_number(:ma_short_period, greater_than: 0)
    |> validate_number(:ma_long_period, greater_than: 0)
    |> validate_number(:maker_fee, greater_than: 0, less_than: 100)
    |> validate_number(:taker_fee, greater_than: 0, less_than: 100)
  end
end
