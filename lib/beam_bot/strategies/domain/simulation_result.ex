defmodule BeamBot.Strategies.Domain.SimulationResult do
  @moduledoc """
  Schema for storing trading simulation results.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias BeamBot.Accounts.User
  alias BeamBot.Strategies.Domain.SimulationTrade
  alias BeamBot.Strategies.Domain.Strategy

  @type t :: %__MODULE__{
          id: integer() | nil,
          trading_pair: String.t() | nil,
          initial_investment: Decimal.t() | nil,
          final_value: Decimal.t() | nil,
          roi_percentage: Decimal.t() | nil,
          start_date: DateTime.t() | nil,
          end_date: DateTime.t() | nil,
          user_id: integer() | nil,
          strategy_id: integer() | nil,
          user: User.t() | nil,
          strategy: Strategy.t() | nil,
          trades: [SimulationTrade.t()] | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @derive {Jason.Encoder,
           only: [
             :trading_pair,
             :initial_investment,
             :final_value,
             :roi_percentage,
             :start_date,
             :end_date,
             :trades
           ]}

  schema "simulation_results" do
    field :trading_pair, :string
    field :initial_investment, :decimal
    field :final_value, :decimal
    field :roi_percentage, :decimal
    field :start_date, :utc_datetime
    field :end_date, :utc_datetime

    belongs_to :user, User
    belongs_to :strategy, Strategy
    has_many :trades, SimulationTrade

    timestamps()
  end

  @doc false
  def changeset(simulation_result, attrs) do
    simulation_result
    |> cast(attrs, [
      :trading_pair,
      :initial_investment,
      :final_value,
      :roi_percentage,
      :start_date,
      :end_date,
      :user_id,
      :strategy_id
    ])
    |> validate_required([
      :trading_pair,
      :initial_investment,
      :final_value,
      :roi_percentage,
      :start_date,
      :end_date,
      :user_id
    ])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:strategy_id)
  end
end
