defmodule BeamBot.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :beam_bot

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &run_seeds_for/1)
    end
  end

  defp run_seeds_for(repo) do
    seed_script = priv_path_for(repo, "seeds.exs")

    if File.exists?(seed_script) do
      Code.eval_file(seed_script)
    else
      {:error, "Seeds file not found for #{inspect(repo)}"}
    end
  end

  defp priv_path_for(repo, filename) do
    app = Keyword.get(repo.config(), :otp_app)
    priv_dir = "#{:code.priv_dir(app)}"

    Path.join([priv_dir, "repo", filename])
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    case Application.load(@app) do
      :ok ->
        :ok

      {:error, {:already_loaded, _}} ->
        :ok

      {:error, reason} ->
        raise "Failed to load application: #{inspect(reason)}"
    end
  end
end
