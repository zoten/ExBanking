defmodule ExBanking.User.UserTest do
  use ExUnit.Case, async: true
  alias ExBanking.User.User

  test "creating new user" do
    assert %User{name: "test"} == User.new("test")
  end

  describe "balance operations" do
    test "add balances" do
      user = User.new("test")

      assert User.currency_balance(user, "euro") == 0

      assert {:ok, user} = User.deposit(user, 15, "euro")
      assert User.currency_balance(user, "euro") == 15

      assert {:ok, user} = User.withdraw(user, 5, "euro")
      assert User.currency_balance(user, "euro") == 10

      assert {:error, :not_enough_money} = User.withdraw(user, 15, "euro")
      # Balance is unchanged
      assert User.currency_balance(user, "euro") == 10
      assert User.currency_balance(user, "donotexist") == 0
    end
  end
end
