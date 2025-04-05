defmodule BeamBot.Strategies.Domain.Indicators do
  @moduledoc """
  Technical indicators used in trading strategies.
  This module provides functions for calculating various technical indicators
  commonly used in trading strategies, such as moving averages, RSI, MACD, etc.
  """

  @doc """
  Calculates the Simple Moving Average (SMA) for a list of prices over a given period.

  ## Parameters
    - prices: List of price values
    - period: The period to calculate the SMA for

  ## Returns
    - The SMA value or nil if there are not enough data points

  ## Examples
      iex> Indicators.sma([1, 2, 3, 4, 5], 3)
      4.0
  """
  def sma(prices, period) when length(prices) >= period do
    prices
    |> Enum.take(-period)
    |> Enum.sum()
    |> Kernel./(period)
  end

  def sma(_prices, _period), do: nil

  @doc """
  Calculates the Exponential Moving Average (EMA) for a list of prices over a given period.

  ## Parameters
    - prices: List of price values
    - period: The period to calculate the EMA for

  ## Returns
    - The EMA value or nil if there are not enough data points

  ## Examples
      iex> Indicators.ema([1, 2, 3, 4, 5], 3)
      4.5
  """
  def ema(prices, period) when length(prices) >= period do
    k = 2 / (period + 1)

    [_head | tail] = Enum.take(prices, period)
    initial_sma = sma(Enum.take(prices, period), period)

    Enum.reduce(tail, initial_sma, fn price, acc ->
      price * k + acc * (1 - k)
    end)
  end

  def ema(_prices, _period), do: nil

  @doc """
  Calculates the Relative Strength Index (RSI) for a list of prices over a given period.

  ## Parameters
    - prices: List of price values
    - period: The period to calculate the RSI for (typically 14)

  ## Returns
    - The RSI value between 0 and 100 or nil if there are not enough data points

  ## Examples
      iex> Indicators.rsi([41, 42, 43, 44, 43, 44, 45, 46, 47, 46, 45, 44, 43, 44, 45], 14)
      50.0
  """
  def rsi(prices, period) when length(prices) > period do
    # Get the price changes
    changes = price_changes(prices)

    if Enum.all?(changes, &(&1 == 0)) do
      # If all changes are 0, RSI is 50
      50.0
    else
      calculate_rsi(changes, period)
    end
  end

  def rsi(_prices, _period), do: nil

  # Private function to calculate RSI to reduce nesting depth
  defp calculate_rsi(changes, period) do
    # Calculate average gains and losses
    {gains, losses} =
      Enum.reduce(changes, {[], []}, fn change, {gains, losses} ->
        cond do
          change > 0 -> {[change | gains], [0 | losses]}
          change < 0 -> {[0 | gains], [abs(change) | losses]}
          true -> {[0 | gains], [0 | losses]}
        end
      end)

    # Take just the period we need
    period_gains = Enum.take(gains, period)
    period_losses = Enum.take(losses, period)

    # Calculate average gain and average loss
    avg_gain = Enum.sum(period_gains) / period
    avg_loss = Enum.sum(period_losses) / period

    # Calculate RS
    rs = if avg_loss == 0, do: 100, else: avg_gain / avg_loss

    # Calculate RSI
    100 - 100 / (1 + rs)
  end

  @doc """
  Calculates the Moving Average Convergence Divergence (MACD) for a list of prices.

  ## Parameters
    - prices: List of price values
    - fast_period: The period for the fast EMA (typically 12)
    - slow_period: The period for the slow EMA (typically 26)
    - signal_period: The period for the signal line (typically 9)

  ## Returns
    - A map containing the MACD line, signal line, and histogram values
    - or nil if there are not enough data points

  ## Examples
      iex> Indicators.macd(prices, 12, 26, 9)
      %{macd_line: 1.5, signal_line: 1.2, histogram: 0.3}
  """
  def macd(prices, fast_period \\ 12, slow_period \\ 26, signal_period \\ 9)

  def macd(prices, fast_period, slow_period, signal_period)
      when length(prices) >= max(fast_period, slow_period) + signal_period do
    # Calculate the fast and slow EMAs
    fast_ema = ema(prices, fast_period)
    slow_ema = ema(prices, slow_period)

    # Calculate the MACD line
    macd_line = fast_ema - slow_ema

    # Generate a list of MACD values to calculate the signal line
    macd_values =
      Enum.map(
        (length(prices) - signal_period)..(length(prices) - 1),
        fn i ->
          sub_prices = Enum.take(prices, i)
          fast_ema = ema(sub_prices, fast_period)
          slow_ema = ema(sub_prices, slow_period)
          fast_ema - slow_ema
        end
      )

    # Calculate the signal line (EMA of MACD line)
    signal_line = ema(macd_values, signal_period)

    # Calculate the histogram (MACD line - signal line)
    histogram = macd_line - signal_line

    %{
      macd_line: macd_line,
      signal_line: signal_line,
      histogram: histogram
    }
  end

  def macd(_prices, _fast_period, _slow_period, _signal_period), do: nil

  @doc """
  Calculates the Bollinger Bands for a list of prices.

  ## Parameters
    - prices: List of price values
    - period: The period for the calculation (typically 20)
    - deviation: The standard deviation multiplier (typically 2)

  ## Returns
    - A map containing the upper band, middle band (SMA), and lower band
    - or nil if there are not enough data points

  ## Examples
      iex> Indicators.bollinger_bands(prices, 20, 2)
      %{upper_band: 45.2, middle_band: 42.1, lower_band: 39.0}
  """
  def bollinger_bands(prices, period \\ 20, deviation \\ 2)

  def bollinger_bands(prices, period, deviation) when length(prices) >= period do
    # Calculate the middle band (SMA)
    middle_band = sma(prices, period)

    # Calculate the standard deviation
    period_prices = Enum.take(prices, -period)
    std_dev = standard_deviation(period_prices, middle_band)

    # Calculate the upper and lower bands
    upper_band = middle_band + std_dev * deviation
    lower_band = middle_band - std_dev * deviation

    %{
      upper_band: upper_band,
      middle_band: middle_band,
      lower_band: lower_band
    }
  end

  def bollinger_bands(_prices, _period, _deviation), do: nil

  # Private helper functions

  defp price_changes(prices) do
    prices
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, current] -> current - prev end)
  end

  defp standard_deviation(values, mean) do
    variance =
      Enum.reduce(values, 0, fn value, acc ->
        acc + :math.pow(value - mean, 2)
      end) / length(values)

    :math.sqrt(variance)
  end
end
