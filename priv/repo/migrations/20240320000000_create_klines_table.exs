defmodule BeamBot.Repo.Migrations.CreateKlinesTable do
  use Ecto.Migration

  def up do
    # Enable TimescaleDB extension
    execute "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE"

    # Create the klines table
    create table(:klines, primary_key: false) do
      add :symbol, :string, null: false
      add :platform, :string, null: false
      add :interval, :string, null: false
      add :timestamp, :timestamptz, null: false
      add :open, :decimal, null: false
      add :high, :decimal, null: false
      add :low, :decimal, null: false
      add :close, :decimal, null: false
      add :volume, :decimal, null: false
      add :quote_volume, :decimal
      add :trades_count, :integer
      add :taker_buy_base_volume, :decimal
      add :taker_buy_quote_volume, :decimal
      add :ignore, :decimal
    end

    # Create a composite primary key
    execute "ALTER TABLE klines ADD PRIMARY KEY (symbol, platform, interval, timestamp)"

    # 2592000000 is 30 days in nanoseconds

    # Convert the table to a TimescaleDB hypertable
    execute "SELECT create_hypertable('klines', 'timestamp', chunk_time_interval => 86400000, if_not_exists => TRUE)"

    # Create indexes for common queries
    create index(:klines, [:symbol, :interval, :timestamp])
    create index(:klines, [:timestamp])
  end

  def down do
    drop table(:klines)
    execute "DROP EXTENSION IF EXISTS timescaledb"
  end
end
