defmodule BeamBot.Exchanges.Domain.Ports.ExchangesRepository do
  @moduledoc """
  This module is responsible for managing the exchanges.
  """

  @callback get_by_identifier(identifier :: String.t()) :: {:ok, map()} | {:error, String.t()}
end
