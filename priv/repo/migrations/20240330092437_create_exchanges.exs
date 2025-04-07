defmodule BeamBot.Repo.Migrations.CreateExchanges do
  use Ecto.Migration

  def change do
    create table(:exchanges) do
      add :name, :string, null: false
      add :identifier, :string, null: false
      add :is_active, :boolean, default: true, null: false

      timestamps()
    end

    create table(:platform_credentials) do
      add :api_key, :string, null: false
      add :api_secret, :string, null: false
      add :exchange_id, references(:exchanges, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :is_active, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:platform_credentials, [:user_id, :exchange_id])

    create table(:trading_pairs) do
      add :exchange_id, references(:exchanges, on_delete: :delete_all), null: false
      add :symbol, :string, null: false
      add :base_asset, :string, null: false
      add :quote_asset, :string, null: false
      add :min_price, :decimal, precision: 30, scale: 10
      add :max_price, :decimal, precision: 30, scale: 10
      add :tick_size, :decimal, precision: 30, scale: 10
      add :min_qty, :decimal, precision: 30, scale: 10
      add :max_qty, :decimal, precision: 30, scale: 10
      add :step_size, :decimal, precision: 30, scale: 10
      add :min_notional, :decimal, precision: 30, scale: 10
      add :is_active, :boolean, default: true, null: false
      add :status, :string, null: false
      add :is_margin_trading, :boolean, default: false, null: false
      add :is_spot_trading, :boolean, default: false, null: false
      add :sync_start_time, :integer, null: true
      add :sync_end_time, :integer, null: true

      timestamps()
    end

    create unique_index(:trading_pairs, [:symbol, :exchange_id])
  end
end
