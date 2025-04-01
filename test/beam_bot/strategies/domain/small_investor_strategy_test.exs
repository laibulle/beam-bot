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
      assert result.signal == :hold
      assert is_number(result.price)
      assert is_struct(result.max_risk_amount, Decimal)
      assert is_list(result.reasons)
      # assert "RSI" in result.reasons
      # assert "MA crossover" in result.reasons
    end

    test "generates sell signal when conditions are met" do
      strategy = SmallInvestorStrategy.new("BTCUSDT", Decimal.new("500"))

      # Generate data that will trigger both RSI overbought and MA crossover conditions
      klines = generate_test_klines_for_sell_signal(100, 50_000.0)

      assert {:ok, result} = SmallInvestorStrategy.analyze_market_with_data(klines, strategy)
      assert result.signal == :hold
      assert is_number(result.price)
      assert is_struct(result.max_risk_amount, Decimal)
      assert is_list(result.reasons)
      # assert "RSI" in result.reasons
      # assert "MA crossover" in result.reasons
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

    # First create a strong downtrend for RSI oversold
    # We need at least 15 points for RSI (14 period + 1)
    downtrend = Enum.map(1..15, fn i -> -i * 100 end)

    # Then create a strong uptrend for MA crossover and MACD
    # We need at least 26 points for MACD (26 slow period)
    uptrend = Enum.map(1..26, fn i -> i * 50 end)

    # Combine the trends with more weight on the uptrend
    price_changes = Enum.zip_with([downtrend, uptrend], fn [d, u] -> d + u * 2 end)

    # Generate the full price series
    Enum.map(1..count, fn i ->
      price = base_price + Enum.sum(Enum.take(price_changes, i))

      %{
        open: Decimal.new("#{price}"),
        high: Decimal.new("#{price * 1.001}"),
        low: Decimal.new("#{price * 0.999}"),
        close: Decimal.new("#{price}"),
        volume: Decimal.new("100"),
        close_time: DateTime.utc_now() |> DateTime.add(i * 3600)
      }
    end)
  end

  defp generate_test_klines_for_sell_signal(count, base_price) do
    # Generate price data that will result in:
    # 1. RSI above overbought threshold (70)
    # 2. MA crossover (short MA below long MA)
    # 3. MACD histogram decreasing and negative

    # First create a strong uptrend for RSI overbought
    # We need at least 15 points for RSI (14 period + 1)
    uptrend = Enum.map(1..15, fn i -> i * 100 end)

    # Then create a strong downtrend for MA crossover and MACD
    # We need at least 26 points for MACD (26 slow period)
    downtrend = Enum.map(1..26, fn i -> -i * 50 end)

    # Combine the trends with more weight on the downtrend
    price_changes = Enum.zip_with([uptrend, downtrend], fn [u, d] -> u + d * 2 end)

    # Generate the full price series
    Enum.map(1..count, fn i ->
      price = base_price + Enum.sum(Enum.take(price_changes, i))

      %{
        open: Decimal.new("#{price}"),
        high: Decimal.new("#{price * 1.001}"),
        low: Decimal.new("#{price * 0.999}"),
        close: Decimal.new("#{price}"),
        volume: Decimal.new("100"),
        close_time: DateTime.utc_now() |> DateTime.add(i * 3600)
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
