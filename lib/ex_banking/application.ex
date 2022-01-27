defmodule ExBanking.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias ExBanking.User.UserStore

  @impl true
  def start(_type, _args) do
    :ok = UserStore.init()

    children = [
      # Starts a worker by calling: ExBanking.Worker.start_link(arg)
      # {ExBanking.Worker, arg}
      {Registry, keys: :unique, name: Registry.Users},
      ExBanking.User.UserSupervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExBanking.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
