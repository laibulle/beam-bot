defmodule HexTate.StateMachine do
  defstruct [:id, :context, :initial, :events, :state]
end
