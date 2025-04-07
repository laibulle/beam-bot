defmodule BeamBot.Domain.Ports.NatsListener do
  @moduledoc """
  Port for NATS message listening functionality.
  """

  @callback start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  @callback subscribe(String.t(), (term() -> :ok)) :: :ok | {:error, term()}
  @callback publish(String.t(), term()) :: :ok | {:error, term()}
end
