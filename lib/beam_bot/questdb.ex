defmodule BeamBot.QuestDB do
  @moduledoc """
  QuestDB client module that provides a connection to QuestDB using REST API.
  """

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    host = Keyword.get(opts, :host, "localhost")
    port = Keyword.get(opts, :port, 9000)
    username = Keyword.get(opts, :username, "admin")
    password = Keyword.get(opts, :password, "quest")

    base_url = "http://#{host}:#{port}"
    auth = Base.encode64("#{username}:#{password}")

    Logger.info("Connecting to QuestDB at #{base_url}")

    {:ok, %{base_url: base_url, auth: auth, opts: opts}}
  end

  @impl true
  def handle_call({:query, query}, _from, %{base_url: base_url, auth: auth} = state) do
    encoded_query = URI.encode_query(%{query: query})

    response =
      Req.get!("#{base_url}/exec?#{encoded_query}",
        headers: [
          {"Authorization", "Basic #{auth}"},
          {"Content-Type", "application/json"}
        ]
      )

    case response.status do
      200 ->
        {:reply, {:ok, response.body}, state}

      _ ->
        Logger.error("Query failed with status #{response.status}: #{inspect(response.body)}")
        {:reply, {:error, response.body}, state}
    end
  rescue
    e ->
      Logger.error("Query failed: #{inspect(e)}")
      {:reply, {:error, e}, state}
  end

  def query(query) do
    GenServer.call(__MODULE__, {:query, query})
  end

  def query!(query) do
    case query(query) do
      {:ok, result} -> result
      {:error, reason} -> raise "Query failed: #{inspect(reason)}"
    end
  end
end
