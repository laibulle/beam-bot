defmodule BeamBot.Strategies.Domain.SmallInvestorStrategy do
  @moduledoc """
  A trading strategy designed for small investors with limited capital.
  This strategy aims to compete with paid Binance bots by focusing on:
  1. Dollar-cost averaging with optimized timing
  2. Momentum-based entry/exit points
  3. Risk management suitable for small portfolios
  """

  require Logger
  alias BeamBot.Strategies.Domain.Indicators

  @klines_repository Application.compile_env(:beam_bot, :klines_repository)

  @type t :: %__MODULE__{
          trading_pair: String.t(),
          investment_amount: Decimal.t(),
          max_risk_percentage: Decimal.t(),
          rsi_oversold_threshold: integer(),
          rsi_overbought_threshold: integer(),
          ma_short_period: integer(),
          ma_long_period: integer(),
          timeframe: String.t(),
          activated_at: DateTime.t() | nil,
          maker_fee: Decimal.t(),
          taker_fee: Decimal.t(),
          user_id: integer()
        }

  defstruct [
    :trading_pair,
    :investment_amount,
    :max_risk_percentage,
    :rsi_oversold_threshold,
    :rsi_overbought_threshold,
    :ma_short_period,
    :ma_long_period,
    :timeframe,
    :activated_at,
    :maker_fee,
    :taker_fee,
    :user_id
  ]

  @doc """
  Creates a new small investor strategy with sensible defaults.

  ## Parameters
    - trading_pair: The trading pair symbol (e.g., "BTCUSDT")
    - investment_amount: Total amount to invest (in quote currency)
    - options: Additional options to customize the strategy

  ## Options
    - max_risk_percentage: Maximum percentage of capital at risk (default: 2%)
    - rsi_oversold_threshold: RSI threshold for oversold condition (default: 30)
    - rsi_overbought_threshold: RSI threshold for overbought condition (default: 70)
    - ma_short_period: Short moving average period (default: 7)
    - ma_long_period: Long moving average period (default: 25)
    - timeframe: Candle timeframe (default: "1h")
    - maker_fee: Maker fee percentage (default: 0.02%)
    - taker_fee: Taker fee percentage (default: 0.1%)

  ## Examples
      iex> SmallInvestorStrategy.new("BTCUSDT", Decimal.new("500"), 1)
      %SmallInvestorStrategy{trading_pair: "BTCUSDT", investment_amount: #Decimal<500>...}
  """
  def new(trading_pair, investment_amount, user_id, options \\ []) do
    # Ensure max_risk_percentage is a Decimal
    max_risk_percentage =
      case Keyword.get(options, :max_risk_percentage) do
        nil -> Decimal.new("2")
        value when is_binary(value) -> Decimal.new(value)
        value when is_float(value) -> Decimal.from_float(value)
        value when is_integer(value) -> Decimal.new(value)
        value when is_struct(value, Decimal) -> value
        # Default to 2% if invalid value provided
        _ -> Decimal.new("2")
      end

    # Parse fee percentages
    maker_fee = Keyword.get(options, :maker_fee, Decimal.new("0.02"))
    taker_fee = Keyword.get(options, :taker_fee, Decimal.new("0.1"))

    %__MODULE__{
      trading_pair: trading_pair,
      investment_amount: investment_amount,
      max_risk_percentage: max_risk_percentage,
      rsi_oversold_threshold: Keyword.get(options, :rsi_oversold_threshold, 30),
      rsi_overbought_threshold: Keyword.get(options, :rsi_overbought_threshold, 70),
      ma_short_period: Keyword.get(options, :ma_short_period, 7),
      ma_long_period: Keyword.get(options, :ma_long_period, 25),
      timeframe: Keyword.get(options, :timeframe, "1h"),
      activated_at: DateTime.utc_now(),
      maker_fee: maker_fee,
      taker_fee: taker_fee,
      user_id: user_id
    }
  end

  @doc """
  Analyzes market data and generates buy/sell signals based on strategy parameters.

  Returns a map with signal type and additional information.
  """
  def analyze_market(strategy) do
    with {:ok, klines} <- fetch_market_data(strategy),
         {:ok, indicators} <- calculate_indicators(klines, strategy) do
      generate_signals(indicators, strategy)
    else
      {:error, reason} ->
        Logger.error("Failed to analyze market: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Analyzes market data using provided historical data instead of fetching it.
  This is used primarily for backtesting and simulation.
  """
  def analyze_market_with_data(klines, strategy) do
    case calculate_indicators(klines, strategy) do
      {:ok, indicators} -> generate_signals(indicators, strategy)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Executes a dollar-cost averaging (DCA) strategy, optimized for the small investor.
  Gradually invests by splitting the capital into smaller parts and investing at optimal times.
  """
  def execute_dca(strategy, num_parts \\ 4) do
    part_amount = Decimal.div(strategy.investment_amount, Decimal.new(num_parts))

    # Implementation would periodically check market conditions
    # and invest the part_amount when conditions are favorable
    # based on the analyze_market function

    # Simplified simulation for demonstration purposes
    {:ok, %{dca_part_amount: part_amount, strategy: strategy}}
  end

  # Private functions

  defp fetch_market_data(strategy) do
    # Fetch historical candlestick data
    limit = max(strategy.ma_long_period * 3, 100)
    @klines_repository.get_klines(strategy.trading_pair, strategy.timeframe, limit)
  end

  defp calculate_indicators(klines, strategy) do
    # Extract closing prices from Kline structs
    closing_prices =
      Enum.map(klines, fn kline ->
        case kline.close do
          %Decimal{} = decimal -> Decimal.to_float(decimal)
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Only calculate indicators if we have enough data
    if length(closing_prices) >= strategy.ma_long_period * 3 do
      # Calculate technical indicators using our Indicators module
      ma_short = Indicators.sma(closing_prices, strategy.ma_short_period)
      ma_long = Indicators.sma(closing_prices, strategy.ma_long_period)
      rsi = Indicators.rsi(closing_prices, 14)
      bollinger = Indicators.bollinger_bands(closing_prices)
      macd = Indicators.macd(closing_prices)

      {:ok,
       %{
         closing_prices: closing_prices,
         ma_short: ma_short,
         ma_long: ma_long,
         rsi: rsi,
         bollinger: bollinger,
         macd: macd,
         latest_price: List.last(closing_prices)
       }}
    else
      {:error, "Not enough data points for indicator calculation"}
    end
  end

  defp generate_signals(indicators, strategy) do
    signal_data = %{
      rsi: check_rsi_signals(indicators.rsi, strategy),
      ma: check_ma_signals(indicators.ma_short, indicators.ma_long),
      bollinger: check_bollinger_signals(indicators.latest_price, indicators.bollinger),
      macd: check_macd_signals(indicators.macd)
    }

    # Combined signals
    buy_signal = buy_signal?(signal_data)
    sell_signal = sell_signal?(signal_data)

    # Determine final signal
    signal =
      cond do
        buy_signal -> :buy
        sell_signal -> :sell
        true -> :hold
      end

    # Calculate position size based on risk management
    case calculate_max_risk(strategy) do
      {:error, reason} ->
        {:error, reason}

      max_risk_amount ->
        # Build signal reasons
        reasons = build_signal_reasons(signal_data, indicators)

        {:ok,
         %{
           signal: signal,
           price: indicators.latest_price,
           max_risk_amount: max_risk_amount,
           indicators: indicators,
           reasons: reasons
         }}
    end
  end

  defp check_rsi_signals(rsi, strategy) do
    case rsi do
      nil ->
        %{
          buy: false,
          sell: false,
          value: nil
        }

      value ->
        %{
          buy: value <= strategy.rsi_oversold_threshold,
          sell: value >= strategy.rsi_overbought_threshold,
          value: value
        }
    end
  end

  defp check_ma_signals(ma_short, ma_long) do
    case {ma_short, ma_long} do
      {nil, _} ->
        %{buy: false, sell: false}

      {_, nil} ->
        %{buy: false, sell: false}

      {short, long} ->
        %{
          buy: short > long,
          sell: short < long
        }
    end
  end

  defp check_bollinger_signals(latest_price, bollinger) do
    case bollinger do
      nil ->
        %{
          buy: false,
          sell: false
        }

      %{lower_band: lower_band, upper_band: upper_band} ->
        %{
          buy: latest_price < lower_band,
          sell: latest_price > upper_band
        }
    end
  end

  defp check_macd_signals(macd) do
    case macd do
      nil ->
        %{
          buy: false,
          sell: false
        }

      %{histogram: histogram} = macd when not is_nil(histogram) ->
        histogram_increasing = histogram > macd.histogram
        histogram_decreasing = histogram < macd.histogram

        %{
          buy: histogram > 0 and histogram_increasing,
          sell: histogram < 0 and histogram_decreasing
        }

      _ ->
        %{
          buy: false,
          sell: false
        }
    end
  end

  defp buy_signal?(signal_data) do
    (signal_data.rsi.buy and signal_data.ma.buy) or
      (signal_data.bollinger.buy and signal_data.rsi.buy) or
      (signal_data.macd.buy and signal_data.rsi.buy)
  end

  defp sell_signal?(signal_data) do
    (signal_data.rsi.sell and signal_data.ma.sell) or
      (signal_data.bollinger.sell and signal_data.rsi.sell) or
      (signal_data.macd.sell and signal_data.rsi.sell)
  end

  defp calculate_max_risk(
         %__MODULE__{investment_amount: amount, max_risk_percentage: risk} = _strategy
       )
       when is_struct(amount, Decimal) and is_struct(risk, Decimal) do
    Decimal.mult(
      amount,
      Decimal.div(risk, Decimal.new("100"))
    )
  end

  defp calculate_max_risk(_strategy) do
    {:error,
     "Invalid strategy configuration: investment_amount and max_risk_percentage must be Decimal values"}
  end

  defp build_signal_reasons(signal_data, indicators) do
    []
    |> add_reason_if(
      signal_data.rsi.buy or signal_data.rsi.sell,
      "RSI: #{Float.round(indicators.rsi, 2)}"
    )
    |> add_reason_if(
      signal_data.ma.buy or signal_data.ma.sell,
      "MA crossover"
    )
    |> add_reason_if(
      signal_data.bollinger.buy or signal_data.bollinger.sell,
      "Bollinger band breakout"
    )
    |> add_reason_if(
      signal_data.macd.buy or signal_data.macd.sell,
      "MACD momentum"
    )
  end

  defp add_reason_if(reasons, condition, reason) do
    if condition, do: [reason | reasons], else: reasons
  end
end
