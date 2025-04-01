defmodule BeamBotWeb.PageControllerTest do
  use BeamBotWeb.ConnCase, async: true

  alias BeamBot.Exchanges.Infrastructure.Adapters.Ecto.TradingPairsRepositoryMock

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Go to Dashboard"
  end
end
