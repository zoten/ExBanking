defmodule ExBanking.Money.Amount do
  @moduledoc """
  To avoid floating point madness, currency is expressed in cents
  """

  @doc """
  Normalizes amount coming in different formats
  Amounts is considered to be given always as currency, so
  10 euro and 10.0 euro are the same value and will be represented
  internally as 1000

      iex> alias ExBanking.Money.Amount
      iex> Amount.from(10.0)
      1000
      iex> Amount.from(10)
      1000
  """
  @spec from(amount :: float() | integer()) :: integer()
  def from(amount) when is_float(amount), do: trunc(amount * 100)
  def from(amount) when is_integer(amount), do: amount * 100

  @doc """
  Present the given currency value as a float

      iex> alias ExBanking.Money.Amount
      iex> Amount.to_presentation(1000)
      10.0
  """
  @spec to_presentation(amount :: integer()) :: float()
  def to_presentation(amount) when is_integer(amount), do: amount / 100
end
