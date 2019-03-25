defmodule SortableTest do
  use ExUnit.Case
  doctest Sortable

  def get_order_code(:min_binary), do: 30
  def get_order_code(x) when is_binary(x), do: 31
  def get_order_code(:max_binary), do: 32
  def get_order_code(:min_float), do: 40
  def get_order_code(x) when is_float(x), do: 41
  def get_order_code(:max_float), do: 44
  def get_order_code(:min_integer), do: 50
  def get_order_code(x) when is_integer(x), do: 51
  def get_order_code(:max_integer), do: 229

  def generate_random_list() do
    bins =
      StreamData.binary()
      |> Enum.take(:rand.uniform(10))

    ints =
      StreamData.integer()
      |> Enum.take(:rand.uniform(10))

    floats =
      StreamData.float()
      |> Enum.take(:rand.uniform(10))

    metas = [
      :min_binary,
      :max_binary,
      :min_float,
      :max_float,
      :min_integer,
      :max_integer
    ]

    Enum.concat([bins, ints, floats, metas])
    |> Enum.shuffle()
    |> Enum.take(:rand.uniform(10))
  end

  def compare_lists([], []), do: true
  def compare_lists([_ | _], []), do: false
  def compare_lists([], [_ | _]), do: true

  def compare_lists([a | x], [b | y]) do
    diff = get_order_code(a) - get_order_code(b)

    cond do
      diff > 0 ->
        false

      diff < 0 ->
        true

      a > b ->
        false

      a < b ->
        true

      a == b ->
        compare_lists(x, y)
    end
  end

  test "it should be able to encode and decode" do
    for _ <- 1..1000 do
      list = generate_random_list()

      assert list == Sortable.decode(Sortable.encode(list))
    end
  end

  test "it should work" do
    for _ <- 1..1000 do
      list =
        Stream.repeatedly(&generate_random_list/0)
        |> Enum.take(10)

      sorted_by_term = list |> Enum.sort(&compare_lists/2)

      sorted_by_sortable =
        list
        |> Enum.map(&Sortable.encode/1)
        |> Enum.sort()
        |> Enum.map(&Sortable.decode/1)

      assert sorted_by_term == sorted_by_sortable
    end
  end
end
