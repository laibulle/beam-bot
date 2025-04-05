defmodule BeamBot.Strategies.Infrastructure.Adapters.Ecto.StrategyRepositoryEcto do
  @moduledoc """
  Ecto implementation of the StrategyRepository behaviour.
  """

  @behaviour BeamBot.Strategies.Domain.Ports.StrategyRepository
  alias BeamBot.Repo
  alias BeamBot.Strategies.Domain.Strategy

  import Ecto.Query

  @impl true
  def save_strategy(strategy) do
    %Strategy{}
    |> Strategy.changeset(strategy)
    |> Repo.insert()
  end

  @impl true
  def get_active_strategies do
    {:ok, Repo.all(from s in Strategy, where: s.status == "active")}
  end

  @impl true
  def get_strategy_by_id(id) do
    case Repo.get(Strategy, id) do
      nil -> {:error, "Strategy not found"}
      strategy -> {:ok, strategy}
    end
  end

  @impl true
  def update_strategy_status(id, status) do
    case Repo.get(Strategy, id) do
      nil ->
        {:error, "Strategy not found"}

      strategy ->
        strategy
        |> Strategy.changeset(%{status: status})
        |> Repo.update()
    end
  end

  @impl true
  def update_last_execution(id, timestamp) do
    case Repo.get(Strategy, id) do
      nil ->
        {:error, "Strategy not found"}

      strategy ->
        strategy
        |> Strategy.changeset(%{last_execution_at: timestamp})
        |> Repo.update()
    end
  end
end
