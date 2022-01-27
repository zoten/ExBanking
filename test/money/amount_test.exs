defmodule ExBanking.Money.AmountTest do
  use ExUnit.Case, async: true
  doctest ExBanking.Money.Amount

  alias ExBanking.Money.Amount

  describe "conversion from number" do
    test "Convert from" do
      assert Amount.from(10.0) == 1000
      assert Amount.from(10) == 1000
    end
  end

  describe "presentation to float" do
    test "present as float" do
      assert Amount.to_presentation(1000) == 10.0
    end
  end
end
