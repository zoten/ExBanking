defmodule ExBanking.User.UserSupervisor do
  @moduledoc """
  This supervisor is responsible game child processes.
  """
  use DynamicSupervisor
  alias __MODULE__
  alias ExBanking.User.UserWorker

  # Client functions

  def create_user(username) do
    case start_child(username) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> {:error, :already_started}
    end
  end

  def all_users do
    # This skips restarting users, but should be enough
    UserSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn
      {:undefined, pid, _, _} ->
        pid

      _ ->
        nil
    end)
    |> Enum.filter(fn pid -> pid != nil end)
  end

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_child(username) do
    # Shorthand to retrieve the child specification from the `child_spec/1` method of the given module.
    child_specification = {UserWorker, username}

    DynamicSupervisor.start_child(__MODULE__, child_specification)
  end

  @impl true
  def init(_arg) do
    # :one_for_one strategy: if a child process crashes, only that process is restarted.
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
