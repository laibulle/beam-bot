defmodule BeamBot.Domain.SyncHistory do
  @moduledoc """
  Schema for storing sync history for a symbol and exchange.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias BeamBot.Exchanges.Exchange

  schema "sync_histories" do
    field :interval, :string
    field :symbol, :string
    field :first_point_date, :utc_datetime
    field :last_point_date, :utc_datetime
    field :from, :utc_datetime
    field :to, :utc_datetime

    belongs_to :exchange, Exchange

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(sync_history, attrs) do
    sync_history
    |> cast(attrs, [
      :interval,
      :symbol,
      :first_point_date,
      :last_point_date,
      :from,
      :to,
      :exchange_id
    ])
    |> validate_required([
      :interval,
      :symbol,
      :first_point_date,
      :last_point_date,
      :from,
      :to,
      :exchange_id
    ])

    # Add other validations as needed, e.g., format checks, date comparisons
  end
end
