defmodule BeamBot.Strategies.Domain.Ports.StrategyRepository do
  @moduledoc """
  Behaviour specification for strategy repository implementations.
  Defines the contract for storing and retrieving trading strategies.
  """

  alias BeamBot.Strategies.Domain.Strategy

  @doc """
  Saves a strategy to the repository.

  ## Parameters
    * strategy - The strategy to save

  ## Returns
    * `{:ok, strategy}` - On successful save
    * `{:error, reason}` - On failure
  """
  @callback save_strategy(map()) :: {:ok, Strategy.t()} | {:error, String.t()}

  @doc """
  Retrieves all active strategies from the repository.

  ## Returns
    * `{:ok, list_of_strategies}` - On successful retrieval
    * `{:error, reason}` - On failure
  """
  @callback get_active_strategies() :: {:ok, list(Strategy.t())} | {:error, String.t()}

  @doc """
  Retrieves a strategy by its ID.

  ## Parameters
    * id - The strategy ID

  ## Returns
    * `{:ok, strategy}` - On successful retrieval
    * `{:error, reason}` - On failure
  """
  @callback get_strategy_by_id(integer()) :: {:ok, Strategy.t()} | {:error, String.t()}

  @doc """
  Updates the status of a strategy.

  ## Parameters
    * id - The strategy ID
    * status - The new status ("active", "paused", or "stopped")

  ## Returns
    * `{:ok, strategy}` - On successful update
    * `{:error, reason}` - On failure
  """
  @callback update_strategy_status(integer(), String.t()) ::
              {:ok, Strategy.t()} | {:error, String.t()}

  @doc """
  Updates the last execution time of a strategy.

  ## Parameters
    * id - The strategy ID
    * timestamp - The execution timestamp

  ## Returns
    * `{:ok, strategy}` - On successful update
    * `{:error, reason}` - On failure
  """
  @callback update_last_execution(integer(), DateTime.t()) ::
              {:ok, Strategy.t()} | {:error, String.t()}
end
