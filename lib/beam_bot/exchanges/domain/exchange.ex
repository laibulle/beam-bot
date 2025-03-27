defmodule BeamBot.Exchanges.Domain.Exchange do
  @moduledoc """
  This module is responsible for managing the exchanges.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          identifier: String.t() | nil,
          is_active: boolean(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "exchanges" do
    field :name, :string
    field :identifier, :string
    field :is_active, :boolean, default: true

    timestamps()
  end

  @doc false
  def changeset(exchange, attrs) do
    exchange
    |> cast(attrs, [:name, :identifier, :is_active])
    |> validate_required([:name, :identifier])
  end
end
