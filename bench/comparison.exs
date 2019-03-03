n = 1000

data = ["Hello", "world", 2018, 11, 11, "special-uuid-here", -3, -1000, 1.2, -1.3]

sext_data = :sext.encode(data)
sortable_data = Sortable.encode(data)
erlang_data = :erlang.term_to_binary(data)

Benchee.run(
  %{
    ":sext.encode" => fn ->
      for _i <- 1..n do
        :sext.encode(data)
      end
    end,
    ":sext.decode" => fn ->
      for _i <- 1..n do
        :sext.decode(sext_data)
      end
    end,
    "Sortable.encode" => fn ->
      for _i <- 1..n do
        Sortable.encode(data)
      end
    end,
    "Sortable.decode" => fn ->
      for _i <- 1..n do
        Sortable.decode(sortable_data)
      end
    end,
    ":erlang.term_to_binary" => fn ->
      for _i <- 1..n do
        :erlang.term_to_binary(data)
      end
    end,
    ":erlang.binary_to_term" => fn ->
      for _i <- 1..n do
        :erlang.binary_to_term(erlang_data)
      end
    end
  },
  memory_time: 2
)
