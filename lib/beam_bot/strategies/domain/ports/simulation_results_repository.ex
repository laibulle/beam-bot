defmodule BeamBot.Strategies.Domain.Ports.SimulationResultsRepository do
  @moduledoc """
  This module defines the behavior for the simulation results repository.
  """

  alias BeamBot.Strategies.Domain.SimulationResult

  @callback save_simulation_result(map()) :: {:ok, SimulationResult.t()} | {:error, term()}
  @callback get_simulation_results_by_user_id(integer()) :: list(SimulationResult.t())
  @callback get_simulation_results_by_trading_pair(String.t()) :: list(SimulationResult.t())
  @callback get_simulation_results_by_strategy_id(integer()) :: list(SimulationResult.t())
end
