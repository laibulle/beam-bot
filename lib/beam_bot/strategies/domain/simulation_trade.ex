defmodule BeamBot.Strategies.Domain.SimulationTrade do
  @moduledoc """
  Schema for storing trades made during a trading simulation.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias BeamBot.Strategies.Domain.SimulationResult

  @type t :: %__MODULE__{
          id: integer() | nil,
          simulation_result_id: integer() | nil,
          date: DateTime.t() | nil,
          type: String.t() | nil,
          price: Decimal.t() | nil,
          amount: Decimal.t() | nil,
          fee: Decimal.t() | nil,
          simulation_result: SimulationResult.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @derive {Jason.Encoder, only: [:date, :type, :price, :amount, :fee]}

  schema "simulation_trades" do
    field :date, :utc_datetime
    field :type, :string
    field :price, :decimal
    field :amount, :decimal
    field :fee, :decimal

    belongs_to :simulation_result, SimulationResult

    timestamps()
  end

  @doc false
  def changeset(simulation_trade, attrs) do
    simulation_trade
    |> cast(attrs, [:simulation_result_id, :date, :type, :price, :amount, :fee])
    |> validate_required([:simulation_result_id, :date, :type, :price, :amount, :fee])
    |> validate_inclusion(:type, ["buy", "sell"])
    |> foreign_key_constraint(:simulation_result_id)
  end
end
