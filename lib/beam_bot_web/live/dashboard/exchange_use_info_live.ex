defmodule BeamBotWeb.ExchangeUseInfoLive do
  use BeamBotWeb, :live_view

  @exchanges_repository Application.compile_env(:beam_bot, :exchanges_repository)
  @platform_credentials_repository Application.compile_env(
                                     :beam_bot,
                                     :platform_credentials_repository
                                   )
  @binance_req_adapter Application.compile_env(:beam_bot, :binance_req_adapter)

  def mount(_params, _session, socket) do
    with {:ok, exchange} <- @exchanges_repository.get_by_identifier("binance"),
         {:ok, credentials} <-
           @platform_credentials_repository.get_by_user_id_and_exchange_id(
             socket.assigns.current_user.id,
             exchange.id
           ),
         {:ok, account_info} <- @binance_req_adapter.get_account_info(credentials) do
      {:ok, assign(socket, account_info: account_info, error: nil)}
    else
      {:error, reason} ->
        {:ok, assign(socket, account_info: nil, error: reason)}
    end
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={BeamBotWeb.Layouts.DashboardComponent}
      id="dashboard"
      current_user={@current_user}
    >
      <div class="p-4">
        <h2 class="text-2xl font-bold mb-4">Account Information</h2>
        <%= if @error do %>
          <div
            class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative"
            role="alert"
          >
            <strong class="font-bold">Error!</strong>
            <span class="block sm:inline">{@error}</span>
          </div>
        <% else %>
          <%= if @account_info do %>
            <div class="bg-white shadow rounded-lg p-6">
              <h3 class="text-lg font-semibold mb-4">Balances</h3>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <%= for balance <- @account_info["balances"] || [] do %>
                  <%= if Decimal.new(balance["free"]) |> Decimal.add(Decimal.new(balance["locked"])) |> Decimal.gt?(Decimal.new(0)) do %>
                    <div class="border rounded p-4">
                      <h4 class="font-bold text-lg mb-2">{balance["asset"]}</h4>
                      <div class="space-y-2">
                        <p>Free: {balance["free"]}</p>
                        <p>Locked: {balance["locked"]}</p>
                        <p class="font-semibold">
                          Total: {Decimal.new(balance["free"])
                          |> Decimal.add(Decimal.new(balance["locked"]))}
                        </p>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>

              <div class="mt-6">
                <h3 class="text-lg font-semibold mb-4">Account Details</h3>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <p><strong>Can Trade:</strong> {@account_info["canTrade"]}</p>
                    <p><strong>Can Withdraw:</strong> {@account_info["canWithdraw"]}</p>
                    <p><strong>Can Deposit:</strong> {@account_info["canDeposit"]}</p>
                  </div>
                  <div>
                    <p><strong>Buyer Commission:</strong> {@account_info["makerCommission"]}</p>
                    <p><strong>Seller Commission:</strong> {@account_info["takerCommission"]}</p>
                    <p><strong>Account Type:</strong> {@account_info["accountType"]}</p>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </.live_component>
    """
  end
end
