defmodule BeamBot.Repo.Migrations.AlterTradingPairsSyncTimes do
  use Ecto.Migration

  def change do
    alter table(:trading_pairs) do
      modify :sync_start_time, :utc_datetime_usec, null: true
      modify :sync_end_time, :utc_datetime_usec, null: true
    end
  end
end
