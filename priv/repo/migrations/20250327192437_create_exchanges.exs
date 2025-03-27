defmodule BeamBot.Repo.Migrations.CreateExchanges do
  use Ecto.Migration

  def change do
    create table(:exchanges) do
      add :name, :string, null: false
      add :provider, :string, null: false
      add :is_active, :boolean, default: true, null: false

      timestamps()
    end

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

      timestamps()
    end

    create index(:trading_pairs, [:exchange_id])
    create index(:trading_pairs, [:symbol])
  end
end
