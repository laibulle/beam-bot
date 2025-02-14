defmodule HexTate.StateMachine do
  defstruct [:id, :context, :initial, :events, :state]

  def send(_state_machine = %__MODULE__{}, _event) do
  end
end
