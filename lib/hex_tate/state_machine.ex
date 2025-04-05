defmodule HexTate.StateMachine do
  @moduledoc """
  This module is responsible for managing the state machine.
  """
  defstruct [:id, :context, :initial, :events, :state]

  def send(%__MODULE__{} = _state_machine, _event) do
  end
end
