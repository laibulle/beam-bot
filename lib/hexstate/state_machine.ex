defmodule Hexstate.StateMachine do
  defstruct [:id, :context, :initial, :events, :state]
end
