defmodule BeamBotWeb.PageControllerTest do
  use BeamBotWeb.ConnCase, async: true

  import Mox

  alias BeamBot.Exchanges.Infrastructure.Adapters.Ecto.TradingPairsRepositoryMock

  setup :verify_on_exit!

  setup do
    expect(TradingPairsRepositoryMock, :list_trading_pairs, fn -> [] end)
    :ok
  end

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Trading Symbols"
  end
end
