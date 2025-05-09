if File.exists?(".env") do
  Dotenv.load()
  Mix.shell().info("Loaded environment variables from .env file")
end

alias BeamBot.Accounts
alias BeamBot.Repo
alias BeamBot.Exchanges.Domain.Exchange
alias BeamBot.Exchanges.Domain.PlatformCredentials

# Create and confirm test user
{:ok, user} =
  Accounts.register_user(%{
    email: System.get_env("DEFAULT_USER_EMAIL"),
    password: System.get_env("DEFAULT_USER_PASSWORD")
  })

# Update the user directly to confirm them
user |> Accounts.User.confirm_changeset() |> Repo.update!()

# Create Binance exchange if it doesn't exist
binance_exchange =
  case Repo.get_by(Exchange, identifier: "binance") do
    nil ->
      %Exchange{
        name: "Binance",
        identifier: "binance",
        is_active: true,
        inserted_at: ~N[2025-04-01 10:20:50],
        updated_at: ~N[2025-04-01 10:20:50]
      }
      |> Repo.insert!()

    existing_exchange ->
      existing_exchange
  end

# Create Binance platform credentials with values from environment variables
%PlatformCredentials{
  api_key: System.get_env("DEFAULT_USER_BINANCE_API_KEY"),
  api_secret: System.get_env("DEFAULT_USER_BINANCE_API_SECRET"),
  exchange_id: binance_exchange.id,
  user_id: user.id
}
|> Repo.insert!()
