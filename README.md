# Sortable

Sortable is a library to provide serialization with order reserved.

Inspired by FoundationDB's [tuple layer][1] and [sext library][2].

## Goal

Design a simple, fast and space-efficiency serialization solution with order reserved for key-value storage use case.

- Simple / Limited Scope: only support list of binaries, floats and integers (scalar types).
- Fast: it's 5~10 times faster than alternative [sext library][2] measured by simple benchmarks.
- Space-efficiency: binary format is designed to be space-dfficiency.
    ```elixir
    iex(1)> Sortable.encode ["hello", 2019, 4, 1]
    <<31, 104, 101, 108, 108, 111, 0, 205, 7, 227, 80, 77>>

    iex(2)> :sext.encode ["hello", 2019, 4, 1]
    <<17, 18, 180, 89, 109, 150, 203, 120, 8, 10, 0, 0, 15, 198, 10, 0, 0, 0, 8, 10, 0, 0, 0, 2, 2>>
    ```

## Example

```elixir
{:ok, db} = :rocksdb.open('#{__DIR__}/rocks.test', create_if_missing: true)

:rocksdb.put(db, Sortable.encode(["folder", 2018, 1, 1, "key-1"]), "value-1", [])
:rocksdb.put(db, Sortable.encode(["folder", 2018, 1, 2, "key-2"]), "value-2", [])
:rocksdb.put(db, Sortable.encode(["folder", 2019, 3, 1, "key-3"]), "value-3", [])

# retrieve everyhing in 2018

{:ok, iterator} =
  :rocksdb.iterator(db,
    iterate_lower_bound: Sortable.encode(["folder", 2018]),
    iterate_upper_bound: Sortable.encode(["folder", 2019])
  )

{:ok, _, "value-1"} = :rocksdb.iterator_move(iterator, :first)
{:ok, _, "value-2"} = :rocksdb.iterator_move(iterator, :next)
{:error, :invalid_iterator} = :rocksdb.iterator_move(iterator, :next)

:rocksdb.iterator_close(iterator)
```

## Installation

The package can be installed by adding `sortable` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sortable, "~> 0.1.0"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/sortable](https://hexdocs.pm/sortable).

## Optimization

Run `ERL_COMPILER_OPTIONS=bin_opt_info mix compile` to ensure binary parsing is optimized.

## Benchmarks

Simple benchmarks for comparison with alternative [sext library][2]:

```
Operating System: macOS"
CPU Information: Intel(R) Core(TM) i7-3720QM CPU @ 2.60GHz
Number of Available Cores: 8
Available memory: 16 GB
Elixir 1.8.1
Erlang 21.2.4

Benchmark suite executing with the following configuration:
warmup: 2 s
time: 5 s
memory time: 2 s
parallel: 1
inputs: none specified
Estimated total run time: 36 s


Benchmarking :sext.decode...
Benchmarking :sext.encode...
Benchmarking Sortable.decode...
Benchmarking Sortable.encode...

Name                      ips        average  deviation         median         99th %
Sortable.decode        510.02        1.96 ms    ±14.32%        1.84 ms        2.94 ms
Sortable.encode        479.97        2.08 ms    ±15.96%        1.94 ms        3.09 ms
:sext.encode            95.23       10.50 ms    ±10.36%       10.07 ms       13.90 ms
:sext.decode            54.13       18.47 ms     ±8.85%       17.59 ms       22.78 ms

Comparison:
Sortable.decode        510.02
Sortable.encode        479.97 - 1.06x slower
:sext.encode            95.23 - 5.36x slower
:sext.decode            54.13 - 9.42x slower

Memory usage statistics:

Name               Memory usage
Sortable.decode         1.27 MB
Sortable.encode         0.97 MB - 0.76x memory usage
:sext.encode            3.18 MB - 2.50x memory usage
:sext.decode            9.72 MB - 7.65x memory usage

**All measurements for memory usage were the same**
```

## License

MIT

[1]: https://github.com/apple/foundationdb/blob/master/design/tuple.md
[2]: https://github.com/uwiger/sext
