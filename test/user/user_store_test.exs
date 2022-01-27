defmodule ExBanking.User.UserStoreTest do
  use ExUnit.Case, async: false
  alias ExBanking.User.UserStore

  @username "test_user"

  setup_all do
    on_exit(fn -> UserStore.flush() end)
    %{}
  end

  setup do
    UserStore.flush()
  end

  test "non existent users" do
    assert false == UserStore.increase(@username, 10)
  end

  test "create, increase, decrease", %{} do
    assert :ok == UserStore.create(@username)
    assert 2 == UserStore.increase(@username, 2)
    assert 1 == UserStore.decrease(@username, 1)
    assert {:ok, {@username, 1}} = UserStore.lookup(@username)
  end
end
