defmodule BeamBot.Repo do
  use Ecto.Repo,
    otp_app: :beam_bot,
    adapter: Ecto.Adapters.Postgres
end
