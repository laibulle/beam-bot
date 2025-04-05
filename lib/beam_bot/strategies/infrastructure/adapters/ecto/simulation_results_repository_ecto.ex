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
    # Convert string keys to atoms if needed
    attrs = convert_map_keys(attrs)

    Repo.transaction(fn ->
      # Create the simulation result
      simulation_result =
        %SimulationResult{}
        |> SimulationResult.changeset(Map.delete(attrs, :trades))
        |> Repo.insert!()

      # Create all trades associated with this simulation result
      trades =
        Enum.map(attrs.trades, fn trade ->
          # Convert trade keys to atoms if needed
          trade = convert_map_keys(trade)

          %SimulationTrade{}
          |> SimulationTrade.changeset(
            Map.put(trade, :simulation_result_id, simulation_result.id)
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

  # Private helper to convert string keys to atoms
  defp convert_map_keys(map) when is_map(map) do
    cond do
      # Handle DateTime structs
      match?(%DateTime{}, map) ->
        map

      # Handle Decimal structs
      match?(%Decimal{}, map) ->
        map

      # Handle other structs
      is_struct(map) ->
        map

      # Handle regular maps
      true ->
        Map.new(map, fn
          {key, value} when is_binary(key) ->
            {String.to_existing_atom(key), convert_map_keys(value)}

          {key, value} ->
            {key, convert_map_keys(value)}
        end)
    end
  end

  defp convert_map_keys(value) when is_list(value) do
    Enum.map(value, &convert_map_keys/1)
  end

  defp convert_map_keys(value), do: value
end
