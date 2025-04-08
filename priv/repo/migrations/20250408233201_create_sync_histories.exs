defmodule BeamBot.Repo.Migrations.CreateSyncHistories do
  use Ecto.Migration

  def change do
    create table(:sync_histories, primary_key: false) do
      add :interval, :string, null: false
      add :symbol, :string, null: false
      add :first_point_date, :utc_datetime, null: false
      add :last_point_date, :utc_datetime, null: false
      add :from, :utc_datetime, null: false
      add :to, :utc_datetime, null: false
      add :exchange_id, references(:exchanges, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:sync_histories, [:symbol, :interval, :exchange_id])
  end
end
