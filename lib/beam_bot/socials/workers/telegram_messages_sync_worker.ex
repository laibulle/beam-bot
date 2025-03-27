defmodule BeamBot.Socials.Workers.TelegramMessagesSyncWorker do
  @moduledoc """
  A GenServer that periodically syncs messages from crypto influencer Telegram channels.
  """
  use GenServer
  require Logger

  alias BeamBot.Socials.Infrastructure.Adapters.Socials.SocialAdapterTelegram

  @sync_interval :timer.minutes(5)

  # List of crypto influencer channels to monitor
  # These are example channel IDs - you'll need to replace them with actual channel IDs
  @crypto_channels [
    # Binance Announcements
    # Replace with actual Binance channel ID
    "-1001234567890",
    # Crypto Signals Alert
    # Replace with actual channel ID
    "-1009876543210",
    # Crypto News Alert
    # Replace with actual channel ID
    "-1002468135790",
    # Crypto Trading Signals
    # Replace with actual channel ID
    "-1001357924680"
  ]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_state) do
    # Verify Telegram bot token is configured
    case Application.get_env(:beam_bot, :telegram_bot_token) do
      nil ->
        Logger.error(
          "Telegram bot token not configured. Please set TELEGRAM_BOT_TOKEN environment variable."
        )

        {:stop, "Missing Telegram bot token"}

      _token ->
        # Trigger immediate sync
        send(self(), :sync_messages)
        # Schedule next sync
        schedule_sync()
        {:ok, %{}}
    end
  end

  @impl true
  def handle_info(:sync_messages, state) do
    case SocialAdapterTelegram.fetch_crypto_influencer_messages(@crypto_channels) do
      {:ok, results} ->
        Enum.each(results, &handle_messages/1)

      {:error, reason} ->
        Logger.error("Failed to sync Telegram messages: #{inspect(reason)}")
    end

    # Schedule next sync
    schedule_sync()
    {:noreply, state}
  end

  defp handle_messages({channel, messages}) do
    case messages do
      {:error, error} ->
        Logger.error("Failed to fetch messages from #{channel}: #{inspect(error)}")

      messages ->
        Logger.info("Successfully fetched #{length(messages)} messages from #{channel}")
        # For now, just log the first message as an example
        if length(messages) > 0 do
          first_message = List.first(messages)
          Logger.info("Latest message from #{channel}: #{inspect(first_message)}")
        end
    end
  end

  defp schedule_sync do
    Process.send_after(self(), :sync_messages, @sync_interval)
  end
end
