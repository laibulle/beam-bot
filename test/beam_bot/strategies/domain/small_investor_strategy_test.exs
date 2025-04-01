defmodule BeamBot.Strategies.Domain.SmallInvestorStrategyTest do
  use ExUnit.Case
  import Mox
  alias BeamBot.Exchanges.Infrastructure.Adapters.Ecto.KlinesRepositoryMock
  alias BeamBot.Strategies.Domain.SmallInvestorStrategy

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "new/3" do
    test "creates strategy with default values" do
      strategy = SmallInvestorStrategy.new("BTCUSDT", Decimal.new("500"))

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
        SmallInvestorStrategy.new("ETHUSDT", Decimal.new("1000"),
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
        SmallInvestorStrategy.new("BTCUSDT", Decimal.new("500"), max_risk_percentage: nil)

      assert strategy.max_risk_percentage == Decimal.new("2")
    end
  end

  describe "analyze_market/1" do
    test "returns error when market data fetch fails" do
      strategy = SmallInvestorStrategy.new("BTCUSDT", Decimal.new("500"))

      expect(KlinesRepositoryMock, :get_klines, fn _trading_pair, _timeframe, _limit ->
        {:error, "Failed to fetch market data"}
      end)

      assert {:error, "Failed to fetch market data"} =
               SmallInvestorStrategy.analyze_market(strategy)
    end

    test "returns error when not enough data points" do
      strategy = SmallInvestorStrategy.new("BTCUSDT", Decimal.new("500"))

      expect(KlinesRepositoryMock, :get_klines, fn _trading_pair, _timeframe, _limit ->
        # Return empty list to trigger insufficient data error
        {:ok, []}
      end)

      assert {:error, "Not enough data points for indicator calculation"} =
               SmallInvestorStrategy.analyze_market(strategy)
    end
  end

  describe "analyze_market_with_data/2" do
    test "generates buy signal when conditions are met" do
      strategy = SmallInvestorStrategy.new("BTCUSDT", Decimal.new("500"))

      # Generate data that will trigger both RSI oversold and MA crossover conditions
      klines = generate_test_klines_for_buy_signal(100, 50_000.0)

      assert {:ok, result} = SmallInvestorStrategy.analyze_market_with_data(klines, strategy)
      assert result.signal == :buy
      assert is_number(result.price)
      assert is_struct(result.max_risk_amount, Decimal)
      assert is_list(result.reasons)
      assert Enum.any?(result.reasons, &String.contains?(&1, "RSI"))
      assert Enum.any?(result.reasons, &String.contains?(&1, "MA crossover"))
    end

    test "generates sell signal when conditions are met" do
      strategy = SmallInvestorStrategy.new("BTCUSDT", Decimal.new("500"))

      # Generate data that will trigger both RSI overbought and MA crossover conditions
      klines = generate_test_klines_for_sell_signal(100, 50_000.0)

      assert {:ok, result} = SmallInvestorStrategy.analyze_market_with_data(klines, strategy)
      assert result.signal == :sell
      assert is_number(result.price)
      assert is_struct(result.max_risk_amount, Decimal)
      assert is_list(result.reasons)
      assert Enum.any?(result.reasons, &String.contains?(&1, "RSI"))
      assert Enum.any?(result.reasons, &String.contains?(&1, "MA crossover"))
    end
  end

  describe "execute_dca/2" do
    test "splits investment into specified number of parts" do
      strategy = SmallInvestorStrategy.new("BTCUSDT", Decimal.new("1000"))

      assert {:ok, result} = SmallInvestorStrategy.execute_dca(strategy, 4)
      assert result.dca_part_amount == Decimal.new("250")
      assert result.strategy == strategy
    end
  end

  # Helper functions

  defp generate_test_klines_for_buy_signal(count, base_price) do
    # Generate price data that will result in:
    # 1. RSI below oversold threshold (30)
    # 2. MA crossover (short MA above long MA)
    # 3. MACD histogram increasing and positive

    # Create a sequence of prices that will:
    # 1. First drop sharply to create oversold RSI
    # 2. Then rise sharply to create MA crossover and positive MACD
    # First 15 points: sharp downtrend for oversold RSI
    # Next 26 points: sharp uptrend for MA crossover and MACD
    # Remaining points: slight uptrend to maintain signals
    prices =
      Enum.map(1..15, fn i -> base_price - i * 1000 end) ++
        Enum.map(1..26, fn i -> base_price - 15 * 1000 + i * 500 end) ++
        Enum.map(1..(count - 41), fn i -> base_price - 15 * 1000 + 26 * 500 + i * 100 end)

    # Generate the full price series
    Enum.map(prices, fn price ->
      %{
        open: Decimal.new("#{price}"),
        high: Decimal.new("#{price * 1.001}"),
        low: Decimal.new("#{price * 0.999}"),
        close: Decimal.new("#{price}"),
        volume: Decimal.new("100"),
        close_time: DateTime.utc_now() |> DateTime.add(3600)
      }
    end)
  end

  defp generate_test_klines_for_sell_signal(count, base_price) do
    # Generate price data that will result in:
    # 1. RSI above overbought threshold (70)
    # 2. MA crossover (short MA below long MA)
    # 3. MACD histogram decreasing and negative

    # Create a sequence of prices that will:
    # 1. First rise sharply to create overbought RSI
    # 2. Then drop sharply to create MA crossover and negative MACD
    # First 15 points: sharp uptrend for overbought RSI
    # Next 26 points: sharp downtrend for MA crossover and MACD
    # Remaining points: slight downtrend to maintain signals
    prices =
      Enum.map(1..15, fn i -> base_price + i * 1000 end) ++
        Enum.map(1..26, fn i -> base_price + 15 * 1000 - i * 500 end) ++
        Enum.map(1..(count - 41), fn i -> base_price + 15 * 1000 - 26 * 500 - i * 100 end)

    # Generate the full price series
    Enum.map(prices, fn price ->
      %{
        open: Decimal.new("#{price}"),
        high: Decimal.new("#{price * 1.001}"),
        low: Decimal.new("#{price * 0.999}"),
        close: Decimal.new("#{price}"),
        volume: Decimal.new("100"),
        close_time: DateTime.utc_now() |> DateTime.add(3600)
      }
    end)
  end
end

# Mock module for testing
defmodule MockKlinesRepo do
  def get_klines(_trading_pair, _timeframe, _limit) do
    {:error, "Failed to fetch market data"}
  end
end
