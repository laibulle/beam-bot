defmodule BeamBot.Strategies.Domain.Strategy do
  @moduledoc """
  Schema for storing trading strategies in the database.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          status: String.t(),
          activated_at: DateTime.t() | nil,
          last_execution_at: DateTime.t() | nil,
          params: map(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "strategies" do
    field :name, :string
    # :active, :paused, :stopped
    field :status, :string
    field :activated_at, :utc_datetime
    field :last_execution_at, :utc_datetime
    # Stores strategy-specific parameters
    field :params, :map

    timestamps()
  end

  @doc """
  Creates a changeset for the strategy.
  """
  def changeset(strategy, attrs) do
    strategy
    |> cast(attrs, [:name, :status, :activated_at, :last_execution_at, :params])
    |> validate_required([:name, :status, :activated_at, :params])
    |> validate_inclusion(:status, ["active", "paused", "stopped"])
  end
end
