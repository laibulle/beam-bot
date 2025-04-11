defmodule BeamBot.Strategies.Domain.SmallInvestorStrategyTest do
  use ExUnit.Case
  import Mox
  alias BeamBot.Exchanges.Infrastructure.Adapters.QuestDB.KlinesTuplesRepositoryMock
  alias BeamBot.Strategies.Domain.SmallInvestorStrategy

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "new/3" do
    test "creates strategy with default values" do
      strategy = SmallInvestorStrategy.new("BTCUSDT", Decimal.new("500"), 1)

      assert strategy.trading_pair == "BTCUSDT"
      assert strategy.investment_amount == Decimal.new("500")
      assert strategy.max_risk_percentage == Decimal.new("2")
      assert strategy.rsi_oversold_threshold == 30
      assert strategy.rsi_overbought_threshold == 70
      assert strategy.ma_short_period == 7
      assert strategy.ma_long_period == 25
      assert strategy.timeframe == "1h"
      assert strategy.maker_fee == Decimal.new("0.02")
      assert strategy.taker_fee == Decimal.new("0.1")
      assert is_struct(strategy.activated_at, DateTime)
    end

    test "creates strategy with custom values" do
      strategy =
        SmallInvestorStrategy.new("ETHUSDT", Decimal.new("1000"), 1,
          max_risk_percentage: "3",
          rsi_oversold_threshold: 25,
          rsi_overbought_threshold: 75,
          ma_short_period: 5,
          ma_long_period: 20,
          timeframe: "4h",
          maker_fee: Decimal.new("0.01"),
          taker_fee: Decimal.new("0.05")
        )

      assert strategy.trading_pair == "ETHUSDT"
      assert strategy.investment_amount == Decimal.new("1000")
      assert strategy.max_risk_percentage == Decimal.new("3")
      assert strategy.rsi_oversold_threshold == 25
      assert strategy.rsi_overbought_threshold == 75
      assert strategy.ma_short_period == 5
      assert strategy.ma_long_period == 20
      assert strategy.timeframe == "4h"
      assert strategy.maker_fee == Decimal.new("0.01")
      assert strategy.taker_fee == Decimal.new("0.05")
    end

    test "handles invalid max_risk_percentage by defaulting to 2%" do
      strategy =
        SmallInvestorStrategy.new("BTCUSDT", Decimal.new("500"), 1, max_risk_percentage: nil)

      assert strategy.max_risk_percentage == Decimal.new("2")
    end
  end

  describe "analyze_market/1" do
    test "returns error when market data fetch fails" do
      strategy = SmallInvestorStrategy.new("BTCUSDT", Decimal.new("500"), 1)

      expect(KlinesTuplesRepositoryMock, :get_klines_tuples, fn _trading_pair,
                                                                _timeframe,
                                                                _limit ->
        {:error, "Failed to fetch market data"}
      end)

      assert {:error, "Failed to fetch market data"} =
               SmallInvestorStrategy.analyze_market(strategy)
    end

    test "returns error when not enough data points" do
      strategy = SmallInvestorStrategy.new("BTCUSDT", Decimal.new("500"), 1)

      expect(KlinesTuplesRepositoryMock, :get_klines_tuples, fn _trading_pair,
                                                                _timeframe,
                                                                _limit ->
        # Return empty list to trigger insufficient data error
        {:ok, []}
      end)

      assert {:error, "Not enough data points for indicator calculation"} =
               SmallInvestorStrategy.analyze_market(strategy)
    end
  end

  describe "analyze_market_with_data/2" do
    # test "generates buy signal when conditions are met" do
    #   IO.puts("\n=== Running Buy Signal Test ===")

    #   strategy =
    #     SmallInvestorStrategy.new("BTCUSDT", Decimal.new("500"),
    #       max_risk_percentage: "2",
    #       rsi_oversold_threshold: 30,
    #       rsi_overbought_threshold: 70,
    #       ma_short_period: 7,
    #       ma_long_period: 25,
    #       timeframe: "1h",
    #       maker_fee: Decimal.new("0.02"),
    #       taker_fee: Decimal.new("0.1")
    #     )

    #   # Generate data that will trigger both RSI oversold and MA crossover conditions
    #   klines = generate_test_klines_for_buy_signal(100, 50_000.0)

    #   # Debug: Print the last few prices to verify the trend
    #   last_prices = Enum.take(klines, 5) |> Enum.map(&Decimal.to_float(&1.close))
    #   IO.puts("\nLast 5 prices: #{inspect(last_prices)}")

    #   assert {:ok, result} = SmallInvestorStrategy.analyze_market_with_data(klines, strategy)

    #   # Debug: Print all indicator values and signal conditions
    #   IO.puts("\nSignal: #{result.signal}")
    #   IO.puts("Price: #{result.price}")
    #   IO.puts("Reasons: #{inspect(result.reasons)}")

    #   if result.indicators do
    #     IO.puts("\nIndicator Values:")
    #     IO.puts("RSI: #{result.indicators.rsi}")
    #     IO.puts("MA Short: #{result.indicators.ma_short}")
    #     IO.puts("MA Long: #{result.indicators.ma_long}")
    #     IO.puts("MACD: #{inspect(result.indicators.macd)}")
    #     IO.puts("Bollinger Bands: #{inspect(result.indicators.bollinger)}")
    #   end

    #   IO.puts("\n=== End Buy Signal Test ===\n")

    #   assert result.signal == :buy
    #   assert is_number(result.price)
    #   assert is_struct(result.max_risk_amount, Decimal)
    #   assert is_list(result.reasons)
    #   assert Enum.any?(result.reasons, &String.contains?(&1, "RSI"))
    #   assert Enum.any?(result.reasons, &String.contains?(&1, "MA crossover"))
    # end

    # test "generates sell signal when conditions are met" do
    #   IO.puts("\n=== Running Sell Signal Test ===")

    #   strategy = SmallInvestorStrategy.new("BTCUSDT", Decimal.new("500"))

    #   # Generate data that will trigger both RSI overbought and MA crossover conditions
    #   klines = generate_test_klines_for_sell_signal(100, 50_000.0)

    #   # Debug: Print the last few prices to verify the trend
    #   last_prices = Enum.take(klines, 5) |> Enum.map(&Decimal.to_float(&1.close))
    #   IO.puts("\nLast 5 prices: #{inspect(last_prices)}")

    #   assert {:ok, result} = SmallInvestorStrategy.analyze_market_with_data(klines, strategy)

    #   # Debug: Print all indicator values and signal conditions
    #   IO.puts("\nSignal: #{result.signal}")
    #   IO.puts("Price: #{result.price}")
    #   IO.puts("Reasons: #{inspect(result.reasons)}")

    #   if result.indicators do
    #     IO.puts("\nIndicator Values:")
    #     IO.puts("RSI: #{result.indicators.rsi}")
    #     IO.puts("MA Short: #{result.indicators.ma_short}")
    #     IO.puts("MA Long: #{result.indicators.ma_long}")
    #     IO.puts("MACD: #{inspect(result.indicators.macd)}")
    #     IO.puts("Bollinger Bands: #{inspect(result.indicators.bollinger)}")
    #   end

    #   IO.puts("\n=== End Sell Signal Test ===\n")

    #   assert result.signal == :sell
    #   assert is_number(result.price)
    #   assert is_struct(result.max_risk_amount, Decimal)
    #   assert is_list(result.reasons)
    #   assert Enum.any?(result.reasons, &String.contains?(&1, "RSI"))
    #   assert Enum.any?(result.reasons, &String.contains?(&1, "MA crossover"))
    # end
  end

  describe "execute_dca/2" do
    test "splits investment into specified number of parts" do
      strategy = SmallInvestorStrategy.new("BTCUSDT", Decimal.new("1000"), 1)

      assert {:ok, result} = SmallInvestorStrategy.execute_dca(strategy, 4)
      assert result.dca_part_amount == Decimal.new("250")
      assert result.strategy == strategy
    end
  end

  # Helper functions

  # defp generate_test_klines_for_sell_signal(count, base_price) do
  #   # Generate a sequence of prices that will definitely trigger sell signals:
  #   # 1. Start with a low price
  #   # 2. Rise sharply to create overbought RSI
  #   # 3. Drop sharply to create MA crossover
  #   # First 30 points: Steeper uptrend from base_price to base_price*2.5
  #   # Next 30 points: Steeper downtrend from base_price*2.5 to base_price*1.2
  #   # Remaining points: Slight downtrend to maintain signals
  #   prices =
  #     Enum.map(1..30, fn i -> base_price + i * (base_price * 1.5 / 30) end) ++
  #       Enum.map(1..30, fn i -> base_price * 2.5 - i * (base_price * 1.3 / 30) end) ++
  #       Enum.map(1..(count - 60), fn i ->
  #         base_price * 1.2 - i * (base_price * 0.1 / (count - 60))
  #       end)

  #   # Generate klines with timestamps
  #   now = DateTime.utc_now()

  #   # Generate klines in reverse chronological order (newest to oldest)
  #   # This ensures indicators look at the most recent prices first
  #   Enum.with_index(prices, fn price, index ->
  #     %{
  #       open: Decimal.new("#{price}"),
  #       high: Decimal.new("#{price * 1.001}"),
  #       low: Decimal.new("#{price * 0.999}"),
  #       close: Decimal.new("#{price}"),
  #       volume: Decimal.new("100"),
  #       close_time: DateTime.add(now, -index * 3600, :second)
  #     }
  #   end)
  #   |> Enum.reverse()
  # end

  # defp generate_test_klines_for_buy_signal(count, base_price) do
  #   # Generate a sequence of prices that will definitely trigger buy signals:
  #   # 1. Start with a high price
  #   # 2. Drop sharply to create oversold RSI
  #   # 3. Rise moderately to create MA crossover
  #   # First 20 points: Sharp downtrend from base_price to base_price/3
  #   # Next 20 points: Moderate uptrend from base_price/3 to base_price/2
  #   # Remaining points: Slight uptrend to maintain signals
  #   prices =
  #     Enum.map(1..20, fn i -> base_price - i * (base_price * 0.67 / 20) end) ++
  #       Enum.map(1..20, fn i -> base_price * 0.33 + i * (base_price * 0.17 / 20) end) ++
  #       Enum.map(1..(count - 40), fn i ->
  #         base_price * 0.5 + i * (base_price * 0.05 / (count - 40))
  #       end)

  #   # Debug: Print the generated prices
  #   IO.puts("Generated Prices: #{inspect(prices)}")

  #   # Generate klines with timestamps
  #   now = DateTime.utc_now()

  #   # Generate klines in reverse chronological order (newest to oldest)
  #   # This ensures indicators look at the most recent prices first
  #   Enum.with_index(prices, fn price, index ->
  #     %{
  #       open: Decimal.new("#{price}"),
  #       high: Decimal.new("#{price * 1.001}"),
  #       low: Decimal.new("#{price * 0.999}"),
  #       close: Decimal.new("#{price}"),
  #       volume: Decimal.new("100"),
  #       close_time: DateTime.add(now, -index * 3600, :second)
  #     }
  #   end)
  #   |> Enum.reverse()
  # end
end

# Mock module for testing
defmodule MockKlinesRepo do
  def get_klines(_trading_pair, _timeframe, _limit) do
    {:error, "Failed to fetch market data"}
  end
end
