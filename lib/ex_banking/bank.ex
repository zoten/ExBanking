defmodule ExBanking.Bank do
  @moduledoc """
  Abstract some specific User and intra-user actions, just to clean up
  ExBanking's interface

  Could be a "user context" specific module but it is not needed to abstract more

  This also acts as a presentatin layer
  """

  alias ExBanking.Money.Amount
  alias ExBanking.User.UserStore
  alias ExBanking.User.UserSupervisor
  alias ExBanking.User.UserWorker

  @spec create_user(binary) :: :ok | {:error, :user_already_exists}
  def create_user(username) when is_binary(username) do
    case UserSupervisor.create_user(username) do
      :ok ->
        UserStore.create(username)
        :ok

      {:error, :already_started} ->
        {:error, :user_already_exists}
    end
  end

  def create_user(_username), do: {:error, :wrong_arguments}

  @spec deposit(String.t(), number(), String.t()) ::
          {:ok, float()}
          | {:error, atom()}
  def deposit(username, amount, currency)
      when is_binary(username) and is_number(amount) and amount >= 0 and is_binary(currency) do
    amount = Amount.from(amount)

    case proxy_exec(username, fn pid ->
           UserWorker.deposit(pid, amount, currency)
         end) do
      {:ok, new_balance} -> {:ok, Amount.to_presentation(new_balance)}
      error -> error
    end
  end

  def deposit(_username, _amount, _currency), do: {:error, :wrong_arguments}

  @spec withdraw(String.t(), number(), String.t()) ::
          {:ok, float()}
          | {:error, atom()}
  def withdraw(username, amount, currency)
      when is_binary(username) and is_number(amount) and amount >= 0 and is_binary(currency) do
    amount = Amount.from(amount)

    case proxy_exec(username, fn pid ->
           UserWorker.withdraw(pid, amount, currency)
         end) do
      {:ok, new_balance} -> {:ok, Amount.to_presentation(new_balance)}
      error -> error
    end
  end

  def withdraw(_username, _amount, _currency), do: {:error, :wrong_arguments}

  @spec get_balance(username :: String.t(), currency :: String.t()) ::
          {:ok, float()}
          | {:error, atom()}
  def get_balance(username, currency) when is_binary(username) and is_binary(currency) do
    case proxy_exec(username, fn pid ->
           UserWorker.get_balance(pid, currency)
         end) do
      {:ok, new_balance} -> {:ok, Amount.to_presentation(new_balance)}
      err -> err
    end
  end

  def get_balance(_username, _currency), do: {:error, :wrong_arguments}

  def send(from_user, to_user, amount, currency)
      when is_binary(from_user) and is_binary(to_user) and is_number(amount) and amount >= 0 and
             is_binary(currency) do
    amount = Amount.from(amount)

    with {:ok, {_sender_pid, _receiver_pid}} <- are_transfer_users_alive?(from_user, to_user),
         :ok <- can_transfer_users_accept_requests(from_user, to_user),
         {:ok, {sender_balance, receiver_balance}} <-
           do_send(from_user, to_user, amount, currency) do
      {
        :ok,
        Amount.to_presentation(sender_balance),
        Amount.to_presentation(receiver_balance)
      }
    else
      err -> err
    end
  end

  def send(_from_user, _to_user, _amount, _currency), do: {:error, :wrong_arguments}

  @doc """
  Drop all users and queues. Exported for testing.
  Use with caution.
  """
  def drop_users do
    # We could use UserStore to get keys/via tuples, but it is not
    # interesting for the use case

    UserSupervisor.all_users()
    |> Enum.each(fn pid -> GenServer.stop(pid) end)

    UserStore.flush()
    :ok
  end

  # Helper function to
  #  * check if process exists (aka user exists)
  #  * check backpressure
  defp proxy_exec(username, callable) do
    with {:ok, pid} <- is_user_alive?(username),
         :ok <- can_user_accept_requests(username) do
      callable.(pid)
    else
      err -> err
    end
  end

  defp is_user_alive?(username) do
    case Registry.lookup(Registry.Users, username) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :user_does_not_exist}
    end
  end

  defp can_user_accept_requests(username, threshold \\ nil) do
    threshold =
      case threshold do
        nil -> UserStore.threshold()
        val when is_integer(val) -> val
      end

    case UserStore.increase(username) do
      val when val > threshold ->
        UserStore.decrease(username)
        {:error, :too_many_requests_to_user}

      val when is_integer(val) ->
        :ok
    end
  end

  # Generalizable, but 2 users is the only case now,
  # so let's specialize for transfer only
  defp are_transfer_users_alive?(sender, receiver) do
    case is_user_alive?(sender) do
      {:ok, sender_pid} ->
        case is_user_alive?(receiver) do
          {:ok, receiver_pid} -> {:ok, {sender_pid, receiver_pid}}
          {:error, :user_does_not_exist} -> {:error, :receiver_does_not_exist}
        end

      {:error, :user_does_not_exist} ->
        {:error, :sender_does_not_exist}
    end
  end

  # Generalizable, but 2 users is the only case now,
  # so let's specialize for transfer only
  defp can_transfer_users_accept_requests(sender, receiver) do
    threshold = UserStore.threshold()

    case can_user_accept_requests(sender, threshold) do
      :ok ->
        case can_user_accept_requests(receiver, threshold) do
          :ok -> :ok
          {:error, :too_many_requests_to_user} -> {:error, :too_many_requests_to_receiver}
        end

      {:error, :too_many_requests_to_user} ->
        {:error, :too_many_requests_to_sender}
    end
  end

  # reusing withdraw and deposit, but could be different functions if
  # different telemetry is needed
  defp do_send(from_user, to_user, amount, currency) do
    with {:ok, sender_balance} <- UserWorker.withdraw(from_user, amount, currency),
         {:ok, receiver_balance} <- UserWorker.deposit(to_user, amount, currency) do
      {:ok, {sender_balance, receiver_balance}}
    else
      err -> err
    end
  end
end
