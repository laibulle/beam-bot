defmodule BeamBot.Strategies.Infrastructure.Adapters.Ecto.SimulationResultsRepositoryEcto do
  @moduledoc """
  Ecto implementation of the simulation results repository.
  """

  @behaviour BeamBot.Strategies.Domain.Ports.SimulationResultsRepository

  alias BeamBot.Repo
  alias BeamBot.Strategies.Domain.{SimulationResult, SimulationTrade}
  import Ecto.Query

  @impl true
  def save_simulation_result(attrs) do
    Repo.transaction(fn ->
      # Create the simulation result
      simulation_result =
        %SimulationResult{}
        |> SimulationResult.changeset(Map.delete(attrs, "trades"))
        |> Repo.insert!()

      # Create all trades associated with this simulation result
      trades =
        Enum.map(attrs["trades"], fn trade ->
          %SimulationTrade{}
          |> SimulationTrade.changeset(
            Map.put(trade, "simulation_result_id", simulation_result.id)
            |> Map.put("date", trade["date"] |> DateTime.from_unix!(:millisecond))
          )
          |> Repo.insert!()
        end)

      %{simulation_result | trades: trades}
    end)
  end

  @impl true
  def get_simulation_results_by_user_id(user_id) do
    SimulationResult
    |> where([sr], sr.user_id == ^user_id)
    |> preload(:trades)
    |> order_by([sr], desc: sr.roi_percentage)
    |> Repo.all()
  end

  @impl true
  def get_simulation_results_by_trading_pair(trading_pair) do
    SimulationResult
    |> where([sr], sr.trading_pair == ^trading_pair)
    |> preload(:trades)
    |> order_by([sr], desc: sr.roi_percentage)
    |> Repo.all()
  end

  @impl true
  def get_simulation_results_by_strategy_id(strategy_id) do
    SimulationResult
    |> where([sr], sr.strategy_id == ^strategy_id)
    |> preload(:trades)
    |> order_by([sr], desc: sr.roi_percentage)
    |> Repo.all()
  end
end
