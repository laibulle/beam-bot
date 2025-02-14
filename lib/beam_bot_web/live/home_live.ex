defmodule BeamBotWeb.HomeLive do
  use Phoenix.LiveView

  alias BeamBot.Infrastructure.Adapters.BinanceReqAdapter

  def render(assigns) do
    ~H"""
    <div>
      <%= for account_info <- @account_info["balances"] do %>
        <%= if account_info["free"] |> parse_value() > 0 do %>
          <div>
            {account_info["asset"]}
            {account_info["free"]}
            {account_info["locked"]}
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, account_info} = BinanceReqAdapter.get_account_info()
    {:ok, exchange_info} = BinanceReqAdapter.get_exchange_info() |> dbg()
    {:ok, socket |> assign(account_info: account_info, exchange_info: exchange_info)}
  end

  defp parse_value(value) do
    {v, _} = Float.parse(value)
    v
  end
end
