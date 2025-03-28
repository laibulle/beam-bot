defmodule BeamBot.Repo.Migrations.CreateKlinesTable do
  use Ecto.Migration

  def up do
    # Enable TimescaleDB extension
    execute "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE"

    # Create the klines table
    create table(:klines, primary_key: false) do
      add :symbol, :string, null: false
      add :interval, :string, null: false
      add :timestamp, :bigint, null: false
      add :open, :float, null: false
      add :high, :float, null: false
      add :low, :float, null: false
      add :close, :float, null: false
      add :volume, :float, null: false
      add :close_time, :bigint
      add :quote_volume, :float
      add :trades_count, :integer
      add :taker_buy_base_volume, :float
      add :taker_buy_quote_volume, :float
      add :ignore, :float
    end

    # Create a composite primary key
    execute "ALTER TABLE klines ADD PRIMARY KEY (symbol, interval, timestamp)"

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
