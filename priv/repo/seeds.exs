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

# Create and confirm test user
{:ok, user} =
  Accounts.register_user(%{
    email: "admin@beambot.com",
    password: "@dmin@admin@admin"
  })

# Update the user directly to confirm them
user |> Accounts.User.confirm_changeset() |> Repo.update!()
