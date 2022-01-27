defmodule ExBanking.User.User do
  @moduledoc """
  Model representing the User entity, containing
  its state and information
  """

  alias __MODULE__

  @doc """
   * `name`        User's name
   * `currencies`  map containing %{"currency" => amount} expressed in cents
  """
  defstruct name: nil,
            currencies: %{}

  @type t :: %User{}

  @spec new(binary()) :: User.t()
  def new(name) when is_binary(name) do
    %User{
      name: name
    }
  end

  @spec deposit(User.t(), any(), any()) :: {:ok, User.t()}
  def deposit(%User{currencies: currencies} = user, amount, currency)
      when is_number(amount) and is_binary(currency) do
    {:ok, %User{user | currencies: do_add_currency(currencies, amount, currency)}}
  end

  @spec withdraw(User.t(), any(), any()) ::
          {:error, :not_enough_money} | {:ok, User.t()}
  def withdraw(%User{currencies: currencies} = user, amount, currency)
      when is_number(amount) and is_binary(currency) do
    if can_withdraw?(currencies, amount, currency) do
      {:ok,
       %User{
         user
         | currencies: do_take_currency(currencies, amount, currency)
       }}
    else
      {:error, :not_enough_money}
    end
  end

  @doc """
  Get's a User balance for a certain currency
  """
  @spec currency_balance(User.t(), String.t()) :: integer()
  def currency_balance(%User{currencies: currencies}, currency) when is_binary(currency) do
    Map.get(currencies, currency, 0)
  end

  # Privates
  defp do_add_currency(currencies, amount, currency)
       when is_integer(amount) and is_binary(currency) do
    Map.update(currencies, currency, amount, &(&1 + amount))
  end

  # Unchecked function, to use after availability checks
  defp do_take_currency(currencies, amount, currency)
       when is_integer(amount) and is_binary(currency),
       do: do_add_currency(currencies, -amount, currency)

  defp can_withdraw?(currencies, amount, currency) do
    balance = Map.get(currencies, currency, 0)
    balance >= amount
  end
end
