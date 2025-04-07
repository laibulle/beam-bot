defmodule BeamBotWeb.TradingPairsLive do
  import Phoenix.Component
  use BeamBotWeb, :live_view

  @trading_pairs_repository Application.compile_env(:beam_bot, :trading_pairs_repository)

  @impl true
  def mount(_params, _session, socket) do
    symbols =
      @trading_pairs_repository.list_trading_pairs()
      |> Enum.filter(&(&1.status == "TRADING"))

    {:ok, assign(socket, symbols: symbols, search: "", loading: false)}
  end

  @impl true
  def handle_info(:update, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, search: search, loading: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={BeamBotWeb.Layouts.DashboardComponent}
      id="dashboard"
      current_user={@current_user}
    >
      <div class="container mx-auto px-4 py-8">
        <h1 class="text-3xl font-bold text-center mb-8">Trading Symbols</h1>

        <div class="max-w-xl mx-auto mb-8">
          <form phx-change="search" phx-submit="search">
            <input
              type="text"
              name="search"
              value={@search}
              class="w-full px-4 py-2 rounded-lg border border-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="Search symbols..."
              autocomplete="off"
            />
          </form>
        </div>

        <%= if @loading do %>
          <div class="flex justify-center mb-4">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
          </div>
        <% end %>

        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6" id="symbolsContainer">
          <%= for symbol <- @symbols do %>
            <div class="symbol-item animate-fade-in" data-symbol={symbol.symbol}>
              <div class="bg-white rounded-lg shadow-md hover:shadow-lg transition-shadow duration-200 h-full">
                <div class="p-4">
                  <div class="flex justify-between items-center mb-2">
                    <h5 class="text-lg font-semibold">{symbol.symbol}</h5>
                    <span class={"px-2 py-1 rounded-full text-xs font-medium #{if symbol.status == "TRADING", do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}"}>
                      {if symbol.status == "TRADING", do: "ACTIVE", else: "INACTIVE"}
                    </span>
                  </div>
                  <div class="text-sm text-gray-600 mb-4 space-y-2">
                    <p><span class="font-medium">Base Asset:</span> {symbol.base_asset}</p>
                    <p><span class="font-medium">Quote Asset:</span> {symbol.quote_asset}</p>
                    <p>
                      <span class="font-medium">Min Price:</span> {if symbol.min_price,
                        do: Decimal.to_string(symbol.min_price, :normal),
                        else: "-"}
                    </p>
                    <p>
                      <span class="font-medium">Max Price:</span> {if symbol.max_price,
                        do: Decimal.to_string(symbol.max_price, :normal),
                        else: "-"}
                    </p>
                    <p>
                      <span class="font-medium">Tick Size:</span> {if symbol.tick_size,
                        do: Decimal.to_string(symbol.tick_size, :normal),
                        else: "-"}
                    </p>
                    <p>
                      <span class="font-medium">Min Qty:</span> {if symbol.min_qty,
                        do: Decimal.to_string(symbol.min_qty, :normal),
                        else: "-"}
                    </p>
                    <p>
                      <span class="font-medium">Max Qty:</span> {if symbol.max_qty,
                        do: Decimal.to_string(symbol.max_qty, :normal),
                        else: "-"}
                    </p>
                    <p>
                      <span class="font-medium">Step Size:</span> {if symbol.step_size,
                        do: Decimal.to_string(symbol.step_size, :normal),
                        else: "-"}
                    </p>
                  </div>
                  <div class="space-y-2">
                    <.link
                      navigate={~p"/dashboard/trading-pair/#{symbol.symbol}"}
                      class="block w-full text-center bg-gray-600 text-white px-4 py-2 rounded-md hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2"
                    >
                      View Details
                    </.link>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </.live_component>
    """
  end
end
