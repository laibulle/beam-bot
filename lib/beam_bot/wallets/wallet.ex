defmodule BeamBot.Wallets.Wallet do
  @moduledoc """
  A module representing a user's wallet.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias BeamBot.Accounts.Domain.User
  alias BeamBot.Exchanges.Domain.Exchange

  schema "wallets" do
    field :balance, :integer
    field :symbol, :string
    belongs_to :exchange, Exchange
    belongs_to :user, User
    timestamps()
  end

  @doc false
  def changeset(wallet, attrs) do
    wallet
    |> cast(attrs, [:user_id, :balance, :symbol, :exchange_id])
    |> validate_required([:user_id, :balance, :symbol, :exchange_id])
  end
end
