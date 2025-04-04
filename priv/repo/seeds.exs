# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     BeamBot.Repo.insert!(%BeamBot.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
alias BeamBot.Accounts
alias BeamBot.Repo
alias BeamBot.Exchanges.Domain.Exchange
alias BeamBot.Exchanges.Domain.PlatformCredentials

# Create and confirm test user
{:ok, user} =
  Accounts.register_user(%{
    email: "admin@beambot.com",
    password: "@dmin@admin@admin"
  })

# Update the user directly to confirm them
user |> Accounts.User.confirm_changeset() |> Repo.update!()

# Create Binance exchange
binance_exchange =
  %Exchange{
    name: "Binance",
    identifier: "binance",
    is_active: true,
    inserted_at: ~N[2025-04-01 10:20:50],
    updated_at: ~N[2025-04-01 10:20:50]
  }
  |> Repo.insert!()

# Create Binance platform credentials
%PlatformCredentials{
  api_key: "api_key",
  api_secret: "api_secret",
  exchange_id: binance_exchange.id,
  user_id: user.id
}
|> Repo.insert!()
