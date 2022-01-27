defmodule ExBanking.User.UserWorker do
  @moduledoc """
  Serializer for actions on a User
  """
  use GenServer

  alias ExBanking.User.User
  alias ExBanking.User.UserStore

  require Logger

  @registry Registry.Users

  # Client functions

  def start_link(username) do
    GenServer.start_link(__MODULE__, username, name: via_tuple(username))
  end

  def deposit(username, amount, currency)
      when is_binary(username) and is_integer(amount) and is_binary(currency),
      do: GenServer.call(via_tuple(username), {:deposit, amount, currency})

  def deposit(pid, amount, currency)
      when is_pid(pid) and is_integer(amount) and is_binary(currency),
      do: GenServer.call(pid, {:deposit, amount, currency})

  def withdraw(username, amount, currency)
      when is_binary(username) and is_integer(amount) and is_binary(currency),
      do: GenServer.call(via_tuple(username), {:withdraw, amount, currency})

  def withdraw(pid, amount, currency)
      when is_pid(pid) and is_integer(amount) and is_binary(currency),
      do: GenServer.call(pid, {:withdraw, amount, currency})

  def get_balance(username, currency) when is_binary(username),
    do: GenServer.call(via_tuple(username), {:get_balance, currency})

  def get_balance(pid, currency) when is_pid(pid),
    do: GenServer.call(pid, {:get_balance, currency})

  @doc """
  Called by the supervisor to retrieve the specification
  of the child process. Restart only on abnormal termination
  """
  def child_spec(process_name) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [process_name]},
      restart: :transient
    }
  end

  def stop(process_name, stop_reason) do
    # Will restart if any reason other than `:normal` is given.
    process_name |> via_tuple() |> GenServer.stop(stop_reason)
  end

  # GenServer callbacks

  @impl true
  def init(username) do
    Logger.info("Starting manager for User [#{username}]")
    {:ok, User.new(username)}
  end

  @impl true
  def handle_call({:deposit, amount, currency}, _from, %User{name: name} = state) do
    Logger.debug("[#{name}] Request to [deposit] [#{amount}] [#{currency}]")
    {:ok, updated_user} = User.deposit(state, amount, currency)

    {:reply, {:ok, User.currency_balance(updated_user, currency)}, updated_user,
     {:continue, :decrease_queue}}
  end

  @impl true
  def handle_call({:withdraw, amount, currency}, _from, %User{name: name} = state) do
    Logger.debug("[#{name}] Request to [withdraw] [#{amount}] [#{currency}]")

    {result, updated_user} =
      case User.withdraw(state, amount, currency) do
        {:ok, updated_user} ->
          {{:ok, User.currency_balance(updated_user, currency)}, updated_user}

        err ->
          {err, state}
      end

    {:reply, result, updated_user, {:continue, :decrease_queue}}
  end

  @impl true
  def handle_call({:get_balance, currency}, _from, %User{} = state) do
    {:reply, {:ok, User.currency_balance(state, currency)}, state, {:continue, :decrease_queue}}
  end

  @impl true
  def handle_continue(:decrease_queue, %User{name: username} = state) do
    decrease_queue(username)
    {:noreply, state}
  end

  # Privates
  defp via_tuple(name),
    do: {:via, Registry, {@registry, name}}

  defp decrease_queue(username), do: UserStore.decrease(username)
end
