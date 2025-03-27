defmodule BeamBotWeb.Layouts.DashboardComponent do
  @moduledoc """
  Dashboard layout component.
  """
  use BeamBotWeb, :live_component

  require Logger

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(:inner_block, assigns.inner_block)
      |> assign(:current_user, assigns.current_user)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns, :nav_links, [
        # %{path: ~p"/dashboard/customized-tales", label: gettext("My Customized Tales")},
        # %{path: ~p"/dashboard/characters", label: gettext("Characters")}
        # %{path: ~p"/dashboard/player", label: gettext("Player")}
      ])

    ~H"""
    <div class="min-h-screen flex flex-col">
      <header class="z-20 sticky top-0 w-full border-b border-purple-200 bg-white/90 backdrop-blur-sm">
        <div class="flex h-16 items-center justify-between px-4 sm:px-6 lg:px-8">
          <div class="flex items-center gap-3">
            <.link navigate={~p"/"} class="flex items-center gap-3">
              <span class="text-2xl">✨</span>
              <span class="text-xl font-semibold text-purple-900">{gettext("FaryTell")}</span>
            </.link>
          </div>

          <nav class="hidden md:flex items-center gap-6">
            <%= for link <- @nav_links do %>
              <.link
                navigate={link.path}
                class="text-sm font-medium text-purple-700 hover:text-purple-900 transition-colors"
              >
                {link.label}
              </.link>
            <% end %>
          </nav>

          <div class="flex items-center gap-4">
            <div class="relative">
              <button
                type="button"
                phx-click={show_menu()}
                class="flex items-center gap-2 rounded-full bg-purple-50 p-2 text-sm font-medium text-purple-900 hover:bg-purple-100 transition-colors"
                aria-label={gettext("Open user menu")}
              >
                <span class="hidden sm:inline-block">
                  {@current_user.email}
                </span>
                <span class="text-lg" aria-hidden="true">👤</span>
              </button>

              <div
                id="user-menu"
                class="hidden absolute right-0 mt-2 w-48 rounded-md bg-white py-1 shadow-lg ring-1 ring-black ring-opacity-5"
              >
                <.link
                  navigate={~p"/users/settings"}
                  class="block px-4 py-2 text-sm text-purple-700 hover:bg-purple-50"
                >
                  {gettext("Profile")}
                </.link>
                <.link
                  href={~p"/users/log_out"}
                  method="delete"
                  class="block px-4 py-2 text-sm text-purple-700 hover:bg-purple-50"
                >
                  {gettext("Log out")}
                </.link>
              </div>
            </div>

            <button
              type="button"
              phx-click={show_mobile_menu()}
              class="md:hidden rounded-lg p-2 text-purple-700 hover:bg-purple-50"
              aria-label={gettext("Toggle mobile menu")}
            >
              <span class="sr-only">{gettext("Toggle navigation")}</span>
              <span class="text-xl" aria-hidden="true">☰</span>
            </button>
          </div>
        </div>

        <div id="mobile-menu" class="hidden md:hidden border-t border-purple-200 bg-white">
          <div class="px-4 py-3 space-y-1">
            <%= for link <- @nav_links do %>
              <.link
                navigate={link.path}
                class="block px-3 py-2 rounded-md text-base font-medium text-purple-700 hover:bg-purple-50"
              >
                {link.label}
              </.link>
            <% end %>
          </div>
        </div>
      </header>

      <main class="flex-1 bg-gradient-to-br from-purple-50/50 to-pink-50/50">
        <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
          <!-- Magical sparkles -->
          <div class="fixed inset-0 pointer-events-none overflow-hidden">
            <div class="animate-float-slow absolute top-20 left-1/4">
              <span class="block text-3xl opacity-20">✨</span>
            </div>
            <div class="animate-float-medium absolute top-40 right-1/3">
              <span class="block text-2xl opacity-10">⭐</span>
            </div>
            <div class="animate-float-fast absolute bottom-1/4 left-1/3">
              <span class="block text-2xl opacity-15">🌟</span>
            </div>
          </div>

          <div class="relative">
            {render_slot(@inner_block)}
          </div>
        </div>
      </main>
    </div>
    """
  end

  defp show_menu(js \\ %JS{}) do
    js
    |> JS.toggle(to: "#user-menu")
    |> JS.remove_class("hidden", to: "#user-menu")
  end

  defp show_processes_menu(js \\ %JS{}) do
    js
    |> JS.toggle(to: "#processes-menu")
    |> JS.remove_class("hidden", to: "#processes-menu")
  end

  defp show_mobile_menu(js \\ %JS{}) do
    js
    |> JS.toggle(to: "#mobile-menu")
    |> JS.remove_class("hidden", to: "#mobile-menu")
  end
end
