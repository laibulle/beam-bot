defmodule BeamBot.Repo.Migrations.CreateStrategies do
  use Ecto.Migration

  def change do
    create table(:strategies) do
      add :name, :string, null: false
      add :status, :string, null: false
      add :activated_at, :utc_datetime, null: false
      add :last_execution_at, :utc_datetime
      add :params, :map, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:strategies, [:name])
    create index(:strategies, [:status])
    create index(:strategies, [:user_id])
  end
end
