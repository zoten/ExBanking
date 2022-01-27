defmodule ExBanking.BankTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias ExBanking.Bank
  alias ExBanking.User.UserStore

  setup_all do
    Application.ensure_all_started(:ex_banking)
  end

  setup do
    Bank.drop_users()
  end

  describe "wrong arguments" do
    test "various wrong arguments" do
      assert {:error, :wrong_arguments} == Bank.create_user(nil)
      assert {:error, :wrong_arguments} == Bank.create_user(12)

      assert {:error, :wrong_arguments} == Bank.deposit(1, 1, "euro")
      assert {:error, :wrong_arguments} == Bank.deposit("user", "one", "euro")
      assert {:error, :wrong_arguments} == Bank.deposit("user", 1, 12)
      assert {:error, :wrong_arguments} == Bank.deposit("user", -1, "euro")

      assert {:error, :wrong_arguments} == Bank.withdraw(1, 1, "euro")
      assert {:error, :wrong_arguments} == Bank.withdraw("user", "one", "euro")
      assert {:error, :wrong_arguments} == Bank.withdraw("user", 1, 12)
      assert {:error, :wrong_arguments} == Bank.withdraw("user", -1, "euro")

      assert {:error, :wrong_arguments} == Bank.get_balance("user", 1)
      assert {:error, :wrong_arguments} == Bank.get_balance(1, "euro")

      assert {:error, :wrong_arguments} == Bank.send("from", "to", 1, 12)
      assert {:error, :wrong_arguments} == Bank.send("from", "to", -1, "euro")
      assert {:error, :wrong_arguments} == Bank.send("from", "to", "1", "euro")
      assert {:error, :wrong_arguments} == Bank.send("from", nil, 1, "euro")
      assert {:error, :wrong_arguments} == Bank.send(nil, "to", 1, "euro")
    end
  end

  describe "single user lifetime" do
    test "users do  not exist" do
      assert {:error, :user_does_not_exist} == Bank.get_balance("do not exist", "euro")
    end

    test "create and operations" do
      username = "test_user"
      assert :ok == Bank.create_user(username)
      assert {:error, :user_already_exists} == Bank.create_user(username)
      assert {:error, :wrong_arguments} == Bank.create_user(12)

      assert Bank.get_balance(username, "euro") == {:ok, 0}

      assert {:ok, 15.0} = Bank.deposit(username, 15, "euro")
      assert {:ok, 20.0} = Bank.deposit(username, 5.0, "euro")
      assert {:ok, 20.0} == Bank.get_balance(username, "euro")

      assert {:ok, 25.0} = Bank.deposit(username, 25, "doubloon")
      assert {:ok, 25.0} == Bank.get_balance(username, "doubloon")

      assert {:ok, 15.0} = Bank.withdraw(username, 5, "euro")
      assert {:error, :not_enough_money} == Bank.withdraw(username, 100, "euro")
    end
  end

  describe "transfer tests" do
    test "normal transfer between users" do
      sender = "sender"
      receiver = "receiver"
      assert :ok == Bank.create_user(sender)
      assert :ok == Bank.create_user(receiver)

      assert {:ok, 15.0} = Bank.deposit(sender, 15, "euro")
      assert {:ok, 10.0, 5.0} = Bank.send(sender, receiver, 5, "euro")
      assert {:error, :not_enough_money} = Bank.send(sender, receiver, 1000, "euro")

      assert {:error, :receiver_does_not_exist} =
               Bank.send(sender, "does_not_exist", 1000, "euro")

      assert {:error, :sender_does_not_exist} =
               Bank.send("does_not_exist", receiver, 1000, "euro")
    end
  end

  describe "interactions between user actions and broker" do
    test "actions count returns at its limits after operation" do
      username = "username"
      assert :ok == Bank.create_user(username)

      assert {:ok, 0} == UserStore.lookup_count(username)
      assert {:ok, 15.0} = Bank.deposit(username, 15, "euro")
      assert {:ok, 0} == UserStore.lookup_count(username)

      # set
      UserStore.set_count(username, 5)
      assert {:ok, 5} == UserStore.lookup_count(username)
      assert {:ok, 20.0} = Bank.deposit(username, 5, "euro")
      assert {:ok, 5} == UserStore.lookup_count(username)
    end
  end

  describe "overload test" do
    test "overloaded user" do
      username = "username"
      assert :ok == Bank.create_user(username)

      set_overloaded(username)

      assert {:error, :too_many_requests_to_user} ==
               Bank.deposit(username, 15, "euro")

      assert {:error, :too_many_requests_to_user} ==
               Bank.withdraw(username, 15, "euro")

      assert {:error, :too_many_requests_to_user} ==
               Bank.get_balance(username, "euro")

      reset_overloaded(username)

      assert {:ok, _} = Bank.deposit(username, 15, "euro")
    end

    test "overloaded transfer between users" do
      sender = "sender"
      receiver = "receiver"
      assert :ok == Bank.create_user(sender)
      assert :ok == Bank.create_user(receiver)

      Bank.deposit(sender, 150, "euro")

      set_overloaded(sender)

      assert {:error, :too_many_requests_to_sender} ==
               Bank.send(sender, receiver, 15, "euro")

      reset_overloaded(sender)

      set_overloaded(receiver)

      assert {:error, :too_many_requests_to_receiver} ==
               Bank.send(sender, receiver, 15, "euro")

      reset_overloaded(receiver)

      assert {:ok, _, _} = Bank.send(sender, receiver, 15, "euro")
    end
  end

  describe "deadlocks test" do
    test "parallel transfers" do
      user0 = "user0"
      user1 = "user1"
      assert :ok == Bank.create_user(user0)
      assert :ok == Bank.create_user(user1)

      Bank.deposit(user0, 150, "euro")
      Bank.deposit(user1, 150, "euro")

      task0 = create_send_task(user0, user1)
      task1 = create_send_task(user1, user0)

      res = Task.await_many([task0, task1])
      assert [:ok, :ok] == res
      assert {:ok, 150.0} == Bank.get_balance(user0, "euro")
      assert {:ok, 150.0} == Bank.get_balance(user1, "euro")
    end

    test "circlular economy" do
      user0 = "user0"
      user1 = "user1"
      user2 = "user2"
      assert :ok == Bank.create_user(user0)
      assert :ok == Bank.create_user(user1)
      assert :ok == Bank.create_user(user2)

      Bank.deposit(user0, 150, "euro")
      Bank.deposit(user1, 150, "euro")
      Bank.deposit(user2, 150, "euro")

      task0 = create_send_task(user0, user1)
      task1 = create_send_task(user1, user2)
      task2 = create_send_task(user2, user0)

      res = Task.await_many([task0, task1, task2])
      assert [:ok, :ok, :ok] == res
      assert {:ok, 150.0} == Bank.get_balance(user0, "euro")
      assert {:ok, 150.0} == Bank.get_balance(user1, "euro")
    end
  end

  defp set_overloaded(user) do
    UserStore.set_count(user, UserStore.threshold())
  end

  defp reset_overloaded(user) do
    UserStore.set_count(user, 0)
  end

  defp create_send_task(from, to) do
    Task.async(fn ->
      Enum.each(
        1..5,
        fn _ ->
          assert {:ok, _, _} = Bank.send(from, to, 1, "euro")
        end
      )

      :ok
    end)
  end
end
