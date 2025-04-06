defmodule BeamBot.Strategies.Domain.MidCapsStrategy do
  @moduledoc """
  A trading strategy designed for mid-cap cryptocurrencies.
  This strategy focuses on:
  1. Identifying promising mid-cap cryptocurrencies (market cap between $1B and $10B)
  2. Using volume and volatility analysis for entry/exit points
  3. Risk management optimized for mid-cap trading
  """

  require Logger
  alias BeamBot.Strategies.Domain.Indicators

  @klines_repository Application.compile_env(:beam_bot, :klines_repository)

  @type t :: %__MODULE__{
          trading_pair: String.t(),
          investment_amount: Decimal.t(),
          max_risk_percentage: Decimal.t(),
          volume_threshold: Decimal.t(),
          volatility_threshold: Decimal.t(),
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
    :volume_threshold,
    :volatility_threshold,
    :ma_short_period,
    :ma_long_period,
    :timeframe,
    :activated_at,
    :maker_fee,
    :taker_fee,
    :user_id
  ]

  @doc """
  Creates a new mid-caps strategy with sensible defaults.

  ## Parameters
    - trading_pair: The trading pair symbol (e.g., "BTCUSDT")
    - investment_amount: Total amount to invest (in quote currency)
    - options: Additional options to customize the strategy

  ## Options
    - max_risk_percentage: Maximum percentage of capital at risk (default: 1.5%)
    - volume_threshold: Minimum 24h volume in USDT (default: 1,000,000)
    - volatility_threshold: Minimum daily volatility percentage (default: 2%)
    - ma_short_period: Short moving average period (default: 5)
    - ma_long_period: Long moving average period (default: 20)
    - timeframe: Candle timeframe (default: "1h")
    - maker_fee: Maker fee percentage (default: 0.02%)
    - taker_fee: Taker fee percentage (default: 0.1%)

  ## Examples
      iex> MidCapsStrategy.new("BTCUSDT", Decimal.new("500"), 1)
      %MidCapsStrategy{trading_pair: "BTCUSDT", investment_amount: #Decimal<500>...}
  """
  def new(trading_pair, investment_amount, user_id, options \\ []) do
    # Ensure max_risk_percentage is a Decimal
    max_risk_percentage =
      case Keyword.get(options, :max_risk_percentage) do
        nil -> Decimal.new("1.5")
        value when is_binary(value) -> Decimal.new(value)
        value when is_float(value) -> Decimal.from_float(value)
        value when is_integer(value) -> Decimal.new(value)
        value when is_struct(value, Decimal) -> value
        # Default to 1.5% if invalid value provided
        _ -> Decimal.new("1.5")
      end

    # Parse fee percentages
    maker_fee = Keyword.get(options, :maker_fee, Decimal.new("0.02"))
    taker_fee = Keyword.get(options, :taker_fee, Decimal.new("0.1"))

    %__MODULE__{
      trading_pair: trading_pair,
      investment_amount: investment_amount,
      max_risk_percentage: max_risk_percentage,
      volume_threshold: Keyword.get(options, :volume_threshold, Decimal.new("1000000")),
      volatility_threshold: Keyword.get(options, :volatility_threshold, Decimal.new("2")),
      ma_short_period: Keyword.get(options, :ma_short_period, 5),
      ma_long_period: Keyword.get(options, :ma_long_period, 20),
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

  # Private functions

  defp fetch_market_data(strategy) do
    # Fetch historical candlestick data
    limit = max(strategy.ma_long_period * 3, 100)
    @klines_repository.get_klines(strategy.trading_pair, strategy.timeframe, limit)
  end

  defp calculate_indicators(klines, strategy) do
    # Extract closing prices and volumes from Kline structs
    {closing_prices, volumes} =
      Enum.map(klines, fn kline ->
        case {kline.close, kline.volume} do
          {%Decimal{} = close, %Decimal{} = volume} ->
            {Decimal.to_float(close), Decimal.to_float(volume)}

          _ ->
            {nil, nil}
        end
      end)
      |> Enum.unzip()
      |> then(fn {prices, vols} ->
        {Enum.reject(prices, &is_nil/1), Enum.reject(vols, &is_nil/1)}
      end)

    # Only calculate indicators if we have enough data
    if length(closing_prices) >= strategy.ma_long_period * 3 do
      # Calculate technical indicators
      ma_short = Indicators.sma(closing_prices, strategy.ma_short_period)
      ma_long = Indicators.sma(closing_prices, strategy.ma_long_period)
      volume_ma = Indicators.sma(volumes, 20)
      volatility = calculate_volatility(closing_prices)

      {:ok,
       %{
         closing_prices: closing_prices,
         volumes: volumes,
         ma_short: ma_short,
         ma_long: ma_long,
         volume_ma: volume_ma,
         volatility: volatility,
         latest_price: List.last(closing_prices),
         latest_volume: List.last(volumes)
       }}
    else
      {:error, "Not enough data points for indicator calculation"}
    end
  end

  defp calculate_volatility(prices) do
    if length(prices) >= 2 do
      [current | [previous | _]] = Enum.take(prices, 2)
      abs((current - previous) / previous * 100)
    else
      nil
    end
  end

  defp generate_signals(indicators, strategy) do
    signal_data = %{
      volume: check_volume_signals(indicators.latest_volume, indicators.volume_ma, strategy),
      volatility: check_volatility_signals(indicators.volatility, strategy),
      ma: check_ma_signals(indicators.ma_short, indicators.ma_long)
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

  defp check_volume_signals(latest_volume, volume_ma, strategy) do
    case {latest_volume, volume_ma} do
      {nil, _} ->
        %{buy: false, sell: false}

      {_, nil} ->
        %{buy: false, sell: false}

      {volume, ma} ->
        %{
          buy: volume > ma and volume > Decimal.to_float(strategy.volume_threshold),
          sell: volume < ma * 0.8
        }
    end
  end

  defp check_volatility_signals(volatility, strategy) do
    case volatility do
      nil ->
        %{buy: false, sell: false}

      value ->
        %{
          buy: value > Decimal.to_float(strategy.volatility_threshold),
          sell: value < Decimal.to_float(strategy.volatility_threshold) * 0.5
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

  defp buy_signal?(signal_data) do
    (signal_data.volume.buy and signal_data.volatility.buy) or
      (signal_data.ma.buy and signal_data.volume.buy)
  end

  defp sell_signal?(signal_data) do
    (signal_data.volume.sell and signal_data.volatility.sell) or
      (signal_data.ma.sell and signal_data.volume.sell)
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
    reasons = []

    reasons =
      if signal_data.volume.buy do
        ["High volume above threshold" | reasons]
      else
        reasons
      end

    reasons =
      if signal_data.volatility.buy do
        ["High volatility above threshold" | reasons]
      else
        reasons
      end

    reasons =
      if signal_data.ma.buy do
        ["MA crossover bullish" | reasons]
      else
        reasons
      end

    reasons =
      if signal_data.volume.sell do
        ["Volume below threshold" | reasons]
      else
        reasons
      end

    reasons =
      if signal_data.volatility.sell do
        ["Low volatility" | reasons]
      else
        reasons
      end

    reasons =
      if signal_data.ma.sell do
        ["MA crossover bearish" | reasons]
      else
        reasons
      end

    reasons
  end
end
