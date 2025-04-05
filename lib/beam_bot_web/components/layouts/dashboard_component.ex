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
        %{path: ~p"/dashboard", label: gettext("Symbols")},
        %{path: ~p"/dashboard/exchange-use-info", label: gettext("Exchange Use Info")},
        %{path: ~p"/dashboard/strategies", label: gettext("Strategies")},
        %{path: ~p"/dashboard/admin", label: gettext("Admin")}
      ])

    ~H"""
    <div class="min-h-screen flex">
      <!-- Left Sidebar -->
      <div class="hidden md:flex md:w-64 md:flex-col">
        <div class="flex min-h-0 flex-1 flex-col border-r border-gray-200 bg-white">
          <div class="flex flex-1 flex-col overflow-y-auto pt-5 pb-4">
            <div class="flex flex-shrink-0 items-center px-4">
              <.link navigate={~p"/"} class="flex items-center gap-2">
                <span class="text-xl"></span>
                <span class="text-lg font-semibold text-gray-900">{gettext("BeamBot")}</span>
              </.link>
            </div>
            <nav class="mt-5 flex-1 space-y-1 bg-white px-2">
              <%= for link <- @nav_links do %>
                <.link
                  navigate={link.path}
                  class="group flex items-center px-2 py-2 text-sm font-medium rounded-md text-gray-600 hover:bg-gray-50 hover:text-gray-900"
                >
                  {link.label}
                </.link>
              <% end %>
            </nav>
          </div>
        </div>
      </div>
      
    <!-- Main Content -->
      <div class="flex flex-1 flex-col">
        <!-- Top Header -->
        <div class="sticky top-0 z-10 flex h-16 flex-shrink-0 bg-white shadow">
          <button
            type="button"
            class="md:hidden px-4 border-r border-gray-200 text-gray-500 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-purple-500"
            phx-click={show_mobile_menu()}
          >
            <span class="sr-only">{gettext("Open sidebar")}</span>
            <span class="text-xl">☰</span>
          </button>
          <div class="flex flex-1 justify-between px-4">
            <div class="flex flex-1">
              <!-- Add search or other controls here if needed -->
            </div>
            <div class="ml-4 flex items-center md:ml-6">
              <div class="relative ml-3">
                <button
                  type="button"
                  phx-click={show_menu()}
                  class="flex rounded-full bg-white text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2"
                  aria-label={gettext("Open user menu")}
                >
                  <span class="sr-only">{gettext("Open user menu")}</span>
                  <div class="flex items-center gap-2 rounded-full bg-gray-50 px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-100">
                    <span class="hidden sm:inline-block">{@current_user.email}</span>
                    <span class="text-lg" aria-hidden="true">👤</span>
                  </div>
                </button>

                <div
                  id="user-menu"
                  class="hidden absolute right-0 mt-2 w-48 rounded-md bg-white py-1 shadow-lg ring-1 ring-black ring-opacity-5"
                >
                  <.link
                    navigate={~p"/users/settings"}
                    class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                  >
                    {gettext("Profile")}
                  </.link>
                  <.link
                    href={~p"/users/log_out"}
                    method="delete"
                    class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                  >
                    {gettext("Log out")}
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Main Content Area -->
        <main class="flex-1">
          <div class="py-6">
            <div class="mx-auto max-w-7xl px-4 sm:px-6 md:px-8">
              <div class="relative">
                {render_slot(@inner_block)}
              </div>
            </div>
          </div>
        </main>
      </div>
      
    <!-- Mobile menu -->
      <div id="mobile-menu" class="hidden md:hidden">
        <div class="fixed inset-0 flex z-40">
          <div class="fixed inset-0 bg-gray-600 bg-opacity-75" phx-click={hide_mobile_menu()}></div>
          <div class="relative flex w-full max-w-xs flex-1 flex-col bg-white">
            <div class="absolute top-0 right-0 -mr-12 pt-2">
              <button
                type="button"
                class="ml-1 flex h-10 w-10 items-center justify-center rounded-full focus:outline-none focus:ring-2 focus:ring-inset focus:ring-white"
                phx-click={hide_mobile_menu()}
              >
                <span class="sr-only">{gettext("Close sidebar")}</span>
                <span class="text-xl">×</span>
              </button>
            </div>
            <div class="h-0 flex-1 overflow-y-auto pt-5 pb-4">
              <div class="flex flex-shrink-0 items-center px-4">
                <.link navigate={~p"/"} class="flex items-center gap-2">
                  <span class="text-xl">✨</span>
                  <span class="text-lg font-semibold text-gray-900">{gettext("BeamBot")}</span>
                </.link>
              </div>
              <nav class="mt-5 space-y-1 px-2">
                <%= for link <- @nav_links do %>
                  <.link
                    navigate={link.path}
                    class="group flex items-center px-2 py-2 text-base font-medium rounded-md text-gray-600 hover:bg-gray-50 hover:text-gray-900"
                  >
                    {link.label}
                  </.link>
                <% end %>
              </nav>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp show_menu(js \\ %JS{}) do
    js
    |> JS.toggle(to: "#user-menu")
    |> JS.remove_class("hidden", to: "#user-menu")
  end

  defp show_mobile_menu(js \\ %JS{}) do
    js
    |> JS.toggle(to: "#mobile-menu")
    |> JS.remove_class("hidden", to: "#mobile-menu")
  end

  defp hide_mobile_menu(js \\ %JS{}) do
    js
    |> JS.toggle(to: "#mobile-menu")
    |> JS.add_class("hidden", to: "#mobile-menu")
  end
end
