defmodule BeamBot.Exchanges.Domain.PlatformCredentials do
  @moduledoc """
  This module is responsible for managing platform credentials for exchanges.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          api_key: String.t() | nil,
          api_secret: String.t() | nil,
          exchange_id: integer() | nil,
          user_id: integer() | nil,
          is_active: boolean(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "platform_credentials" do
    field :api_key, :string
    field :api_secret, :string
    field :is_active, :boolean, default: true

    belongs_to :exchange, BeamBot.Exchanges.Domain.Exchange
    belongs_to :user, BeamBot.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(platform_credentials, attrs) do
    platform_credentials
    |> cast(attrs, [:api_key, :api_secret, :is_active, :exchange_id, :user_id])
    |> validate_required([:api_key, :api_secret, :exchange_id, :user_id])
    |> foreign_key_constraint(:exchange_id)
    |> foreign_key_constraint(:user_id)
  end
end
