defmodule BeamBot.Repo.Migrations.CreateSocialMessages do
  use Ecto.Migration

  def change do
    create table(:social_messages) do
      add :source, :string, null: false
      add :platform, :string, null: false

      timestamps()
    end
  end
end
