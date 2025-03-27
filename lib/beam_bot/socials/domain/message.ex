defmodule BeamBot.Socials.Domain.Message do
  @moduledoc """
  This module is responsible for managing the messages.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          source: String.t() | nil,
          platform: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "social_messages" do
    field :source, :string
    field :platform, :string

    timestamps()
  end

  @doc false
  def changeset(exchange, attrs) do
    exchange
    |> cast(attrs, [:source, :platform])
    |> validate_required([:source, :platform])
  end
end
