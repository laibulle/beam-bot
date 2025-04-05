defmodule BeamBot.Repo.Migrations.CreateSimulationResults do
  use Ecto.Migration

  def change do
    create table(:simulation_results) do
      add :trading_pair, :string, null: false
      add :initial_investment, :decimal, precision: 30, scale: 10, null: false
      add :final_value, :decimal, precision: 30, scale: 10, null: false
      add :roi_percentage, :decimal, precision: 10, scale: 2, null: false
      add :start_date, :utc_datetime, null: false
      add :end_date, :utc_datetime, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :strategy_id, references(:strategies, on_delete: :delete_all), null: true

      timestamps()
    end

    create table(:simulation_trades) do
      add :simulation_result_id, references(:simulation_results, on_delete: :delete_all),
        null: false

      add :date, :utc_datetime, null: false
      add :type, :string, null: false
      add :price, :decimal, precision: 30, scale: 10, null: false
      add :amount, :decimal, precision: 30, scale: 10, null: false
      add :fee, :decimal, precision: 30, scale: 10, null: false

      timestamps()
    end

    create index(:simulation_results, [:user_id])
    create index(:simulation_results, [:strategy_id])
    create index(:simulation_results, [:trading_pair])
    create index(:simulation_trades, [:simulation_result_id])
  end
end
