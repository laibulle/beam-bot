defmodule BeamBot.Repo.Migrations.CreateExchanges do
  use Ecto.Migration

  def change do
    create table(:exchanges) do
      add :name, :string, null: false
      add :provider, :string, null: false
      add :is_active, :boolean, default: true, null: false

      timestamps()
    end
  end
end
