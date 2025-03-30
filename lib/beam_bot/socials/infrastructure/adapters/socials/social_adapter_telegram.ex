defmodule BeamBot.Socials.Infrastructure.Adapters.Socials.SocialAdapterTelegram do
  @moduledoc """
  This module is responsible for managing the social media platform.
  """
  require Logger

  @base_url "https://api.telegram.org/bot"

  @doc """
  Fetches messages from a Telegram channel or group.

  ## Example
    iex > {:ok, messages} = BeamBot.Socials.Infrastructure.Adapters.Socials.SocialAdapterTelegram.fetch_messages(-1001929292929292929, 100)
  """
  def fetch_messages(channel_id, limit \\ 100) do
    token = Application.get_env(:beam_bot, :telegram_bot_token)
    url = "#{@base_url}#{token}/getChatHistory"

    case Req.get(url,
           params: %{
             chat_id: channel_id,
             limit: limit,
             offset: 0
           }
         ) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        process_messages(body)

      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to fetch Telegram messages: #{inspect(body)}")
        {:error, "Failed to fetch messages with status #{status}"}

      {:error, error} ->
        Logger.error("Error fetching Telegram messages: #{inspect(error)}")
        {:error, "Failed to fetch messages: #{inspect(error)}"}
    end
  end

  @doc """
  Fetches messages from multiple crypto influencer channels.
  """
  def fetch_crypto_influencer_messages(channels) when is_list(channels) do
    results =
      Enum.map(channels, fn channel ->
        case fetch_messages(channel) do
          {:ok, messages} -> {channel, messages}
          {:error, error} -> {channel, error}
        end
      end)

    {:ok, results}
  end

  defp process_messages(%{"ok" => true, "result" => messages}) do
    processed_messages =
      Enum.map(messages, fn message ->
        %{
          id: message["message_id"],
          text: message["text"],
          date: message["date"],
          chat_id: message["chat"]["id"],
          chat_title: message["chat"]["title"],
          from: get_in(message, ["from", "username"]) || "Unknown",
          entities: message["entities"] || [],
          reply_to_message: message["reply_to_message"]
        }
      end)

    {:ok, processed_messages}
  end

  defp process_messages(body) do
    Logger.error("Unexpected Telegram API response: #{inspect(body)}")
    {:error, "Unexpected API response format"}
  end
end
