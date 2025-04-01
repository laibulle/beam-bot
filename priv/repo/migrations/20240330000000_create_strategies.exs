defmodule BeamBot.Repo.Migrations.CreateStrategies do
  use Ecto.Migration

  def change do
    create table(:strategies) do
      add :trading_pair, :string, null: false
      add :timeframe, :string, null: false
      add :investment_amount, :decimal, null: false
      add :max_risk_percentage, :decimal, null: false
      add :rsi_oversold_threshold, :integer, null: false
      add :rsi_overbought_threshold, :integer, null: false
      add :ma_short_period, :integer, null: false
      add :ma_long_period, :integer, null: false
      add :status, :string, null: false
      add :activated_at, :utc_datetime, null: false
      add :last_execution_at, :utc_datetime
      add :maker_fee, :decimal, null: false
      add :taker_fee, :decimal, null: false

      timestamps()
    end

    create index(:strategies, [:trading_pair])
    create index(:strategies, [:status])
  end
end
