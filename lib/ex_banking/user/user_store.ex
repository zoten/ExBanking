defmodule ExBanking.User.UserStore do
  @moduledoc """
  Storage for User information (queue)
  """
  @table :users

  @type user_data :: {binary(), integer()}

  @threshold 10

  @spec init :: :ok
  def init do
    :ets.new(@table, [:set, :public, :named_table])
    :ok
  end

  def threshold, do: @threshold

  @doc """
  Creates a new user or replaces the existing one.
  This is wanted, to allow UserWorker to initialize its queue in case of
  abnormal restarts
  """
  @spec create(username :: String.t()) :: :ok
  def create(username) do
    :ets.insert(@table, {username, 0})
    :ok
  end

  @doc """
  Exported mostly for test
  """
  def set_count(username, num) do
    # is this a hack to set precisely a counter?
    # could use probably select_replace
    :ets.update_counter(@table, username, {2, 1, 0, num})
  end

  @spec increase(username :: String.t(), count :: number()) :: integer() | boolean()
  def increase(username, count \\ 1) do
    :ets.update_counter(@table, username, {2, count})
  rescue
    _e in ArgumentError ->
      false
  end

  @spec decrease(username :: String.t(), count :: number()) :: integer() | boolean()
  def decrease(username, count \\ 1) do
    :ets.update_counter(@table, username, {2, -count})
  rescue
    _e in ArgumentError ->
      false
  end

  @spec lookup(username :: String.t()) :: {:ok, user_data()} | {:error, :not_found}
  def lookup(username) do
    case :ets.lookup(@table, username) do
      [] -> {:error, :not_found}
      [value] -> {:ok, value}
    end
  end

  @doc """
  Gets the queue size for a user
  """
  @spec lookup_count(username :: String.t()) :: {:ok, integer()} | {:error, :not_found}
  def lookup_count(username) do
    case :ets.lookup(@table, username) do
      [] -> {:error, :not_found}
      [{_username, count}] -> {:ok, count}
    end
  end

  @spec flush :: :ok
  def flush do
    :ets.delete_all_objects(@table)
    :ok
  end
end
