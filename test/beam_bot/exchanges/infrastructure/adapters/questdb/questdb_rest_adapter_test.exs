defmodule BeamBot.Exchanges.Infrastructure.Adapters.QuestDB.QuestDBRestAdapterTest do
  @moduledoc """
  This module is responsible for testing the QuestDB REST adapter.
  """
  use ExUnit.Case, async: true

  alias BeamBot.Exchanges.Infrastructure.Adapters.QuestDB.QuestDBRestAdapter

  describe "get_klines_tuples/5" do
    test "returns dataset on successful query" do
      QuestDBRestAdapter.drop_tuples("FAKE", "1h")
      Process.sleep(1000)

      lines = [
        [
          1_499_040_000_000,
          0.01634790,
          0.8,
          0.015758,
          0.015771,
          148_976.11427815,
          1_499_644_799_999,
          2434.19055334,
          308,
          1756.87402397,
          28.46694368,
          17_928_899.62484339
        ]
      ]

      assert QuestDBRestAdapter.save_klines_tuples("FAKE", "1h", lines) == {:ok, 1}

      Process.sleep(5000)

      assert {:ok,
              [
                [
                  # Open price
                  0.0163479,
                  # High price
                  0.8,
                  # Low price
                  0.015758,
                  # Close price
                  0.015771,
                  # Volume
                  148_976.11427815,
                  # Close time (timestamp)
                  1_499_644_799_999,
                  # Quote asset volume
                  2434.19055334,
                  # Number of trades
                  308,
                  # Taker buy base asset volume
                  1756.87402397,
                  # Taker buy quote asset volume
                  28.46694368,
                  # Open time (ISO 8601 format)
                  "2017-07-03T00:00:00.000000Z"
                ]
              ]} ==
               QuestDBRestAdapter.get_klines_tuples(
                 "FAKE",
                 "1h"
               )
    end
  end
end
