defmodule HexTate.StateMachine do
  defstruct [:id, :context, :initial, :events, :state]

  def send(state_machine = %__MODULE__{}, event) do
  end
end
