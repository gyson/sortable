defmodule SortableTest do
  use ExUnit.Case
  doctest Sortable

  def generate_random_list() do
    bins =
      StreamData.binary()
      |> Enum.take(:rand.uniform(100))

    ints =
      StreamData.integer()
      |> Enum.take(:rand.uniform(100))

    Enum.concat(bins, ints)
    |> Enum.shuffle()
  end

  test "it should work" do
    for _ <- 1..100 do
      list =
        Stream.repeatedly(&generate_random_list/0)
        |> Enum.take(100)

      sorted_by_term = list |> Enum.sort()

      sorted_by_sortable =
        list
        |> Enum.map(&Sortable.encode/1)
        |> Enum.sort()
        |> Enum.map(&Sortable.decode/1)

      assert sorted_by_term == sorted_by_sortable
    end
  end
end
