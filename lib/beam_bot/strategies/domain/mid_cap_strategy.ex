defmodule BeamBot.Strategies.Domain.MidCapStrategy do
  @moduledoc """
  A trading strategy specifically designed for mid-cap cryptocurrencies.
  This strategy focuses on:
  1. Volume-weighted momentum analysis
  2. Market cap rank tracking
  3. Risk management optimized for mid-cap volatility
  4. Trend following with volume confirmation
  """

  require Logger
  alias BeamBot.Strategies.Domain.Indicators

  @klines_repository Application.compile_env(:beam_bot, :klines_repository)

  @type t :: %__MODULE__{
          trading_pair: String.t(),
          investment_amount: Decimal.t(),
          max_risk_percentage: Decimal.t(),
          min_market_cap_rank: integer(),
          max_market_cap_rank: integer(),
          volume_threshold: Decimal.t(),
          momentum_period: integer(),
          trend_period: integer(),
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
    :min_market_cap_rank,
    :max_market_cap_rank,
    :volume_threshold,
    :momentum_period,
    :trend_period,
    :timeframe,
    :activated_at,
    :maker_fee,
    :taker_fee,
    :user_id
  ]

  @doc """
  Creates a new mid-cap strategy with sensible defaults.

  ## Parameters
    - trading_pair: The trading pair symbol (e.g., "BTCUSDT")
    - investment_amount: Total amount to invest (in quote currency)
    - user_id: The ID of the user implementing the strategy
    - options: Additional options to customize the strategy

  ## Options
    - max_risk_percentage: Maximum percentage of capital at risk (default: 3%)
    - min_market_cap_rank: Minimum market cap rank to consider (default: 20)
    - max_market_cap_rank: Maximum market cap rank to consider (default: 100)
    - volume_threshold: Minimum volume threshold (default: 1.5x average)
    - momentum_period: Period for momentum calculation (default: 14)
    - trend_period: Period for trend analysis (default: 25)
    - timeframe: Candle timeframe (default: "4h")
    - maker_fee: Maker fee percentage (default: 0.02%)
    - taker_fee: Taker fee percentage (default: 0.1%)

  ## Examples
      iex> MidCapStrategy.new("SOLUSDT", Decimal.new("1000"), 1)
      %MidCapStrategy{trading_pair: "SOLUSDT", investment_amount: #Decimal<1000>...}
  """
  def new(trading_pair, investment_amount, user_id, options \\ []) do
    # Ensure max_risk_percentage is a Decimal
    max_risk_percentage =
      case Keyword.get(options, :max_risk_percentage) do
        nil -> Decimal.new("3")
        value when is_binary(value) -> Decimal.new(value)
        value when is_float(value) -> Decimal.from_float(value)
        value when is_integer(value) -> Decimal.new(value)
        value when is_struct(value, Decimal) -> value
        _ -> Decimal.new("3")
      end

    # Parse fee percentages
    maker_fee = Keyword.get(options, :maker_fee, Decimal.new("0.02"))
    taker_fee = Keyword.get(options, :taker_fee, Decimal.new("0.1"))

    %__MODULE__{
      trading_pair: trading_pair,
      investment_amount: investment_amount,
      max_risk_percentage: max_risk_percentage,
      min_market_cap_rank: Keyword.get(options, :min_market_cap_rank, 20),
      max_market_cap_rank: Keyword.get(options, :max_market_cap_rank, 100),
      volume_threshold: Keyword.get(options, :volume_threshold, Decimal.new("1.5")),
      momentum_period: Keyword.get(options, :momentum_period, 14),
      trend_period: Keyword.get(options, :trend_period, 25),
      timeframe: Keyword.get(options, :timeframe, "4h"),
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
    limit = max(strategy.trend_period * 3, 100)
    @klines_repository.get_klines(strategy.trading_pair, strategy.timeframe, limit)
  end

  defp calculate_indicators(klines, strategy) do
    # Extract prices and volumes from Kline structs
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
    if length(closing_prices) >= strategy.trend_period * 3 do
      # Calculate technical indicators
      momentum = Indicators.momentum(closing_prices, strategy.momentum_period)
      trend = Indicators.sma(closing_prices, strategy.trend_period)
      volume_sma = Indicators.sma(volumes, strategy.trend_period)
      latest_volume = List.last(volumes)
      latest_price = List.last(closing_prices)

      {:ok,
       %{
         closing_prices: closing_prices,
         volumes: volumes,
         momentum: momentum,
         trend: trend,
         volume_sma: volume_sma,
         latest_volume: latest_volume,
         latest_price: latest_price
       }}
    else
      {:error, "Not enough data points for indicator calculation"}
    end
  end

  defp generate_signals(indicators, strategy) do
    signal_data = %{
      momentum: check_momentum_signals(indicators.momentum),
      trend: check_trend_signals(indicators.trend, indicators.latest_price),
      volume: check_volume_signals(indicators.latest_volume, indicators.volume_sma, strategy)
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
        reasons = build_signal_reasons(signal_data)

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

  defp check_momentum_signals(momentum) do
    case momentum do
      nil ->
        %{buy: false, sell: false, value: nil}

      value ->
        %{
          buy: value > 0,
          sell: value < 0,
          value: value
        }
    end
  end

  defp check_trend_signals(trend, latest_price) do
    case {trend, latest_price} do
      {nil, _} ->
        %{buy: false, sell: false}

      {_, nil} ->
        %{buy: false, sell: false}

      {trend_value, price} ->
        %{
          buy: price > trend_value,
          sell: price < trend_value
        }
    end
  end

  defp check_volume_signals(latest_volume, volume_sma, strategy) do
    case {latest_volume, volume_sma} do
      {nil, _} ->
        %{buy: false, sell: false}

      {_, nil} ->
        %{buy: false, sell: false}

      {volume, sma} ->
        threshold = Decimal.to_float(strategy.volume_threshold)

        %{
          buy: volume > sma * threshold,
          sell: volume < sma * (1 / threshold)
        }
    end
  end

  defp buy_signal?(signal_data) do
    signal_data.momentum.buy and
      signal_data.trend.buy and
      signal_data.volume.buy
  end

  defp sell_signal?(signal_data) do
    signal_data.momentum.sell and
      signal_data.trend.sell and
      signal_data.volume.sell
  end

  defp calculate_max_risk(strategy) do
    try do
      risk_amount = Decimal.mult(strategy.investment_amount, strategy.max_risk_percentage)
      Decimal.div(risk_amount, Decimal.new("100"))
    rescue
      _ -> {:error, "Invalid risk calculation parameters"}
    end
  end

  defp build_signal_reasons(signal_data) do
    reasons = []

    reasons =
      if signal_data.momentum.buy do
        ["Positive momentum"] ++ reasons
      else
        reasons
      end

    reasons =
      if signal_data.trend.buy do
        ["Price above trend"] ++ reasons
      else
        reasons
      end

    reasons =
      if signal_data.volume.buy do
        ["High volume confirmation"] ++ reasons
      else
        reasons
      end

    reasons
  end
end
