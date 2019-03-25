defmodule Sortable do
  @moduledoc """

  Sortable is a library to provide serialization with order reserved.

  """

  use Bitwise

  @on_load :prepare
  @zero_key Sortable.Zero

  @doc false
  def prepare() do
    :persistent_term.put(@zero_key, :binary.compile_pattern(<<0>>))
    :ok
  end

  # order with code:
  #
  # :min_binary(30) < binary(31) < :max_binary(32) <
  # :min_float(40) < float-neg(41) < 0.0(42) < float-pos(43) < :max_float(44) <
  # :min_integer(50) < neg_integer(56~75) < integer 0~127 (76~203) < pos_integer(204~223) < :max_integer(229)
  #
  # 51~55 reserved for big_neg_int
  # 224~228 reserved for big_pos_int
  # 0~29, 33~39, 44~49, 230~254 are reserved for future extension

  @type t :: [
          :min_binary
          | binary()
          | :max_binary
          | :min_float
          | float()
          | :max_float
          | :min_integer
          | integer()
          | :max_integer
        ]

  @doc """

  Encode a list of binaries, floats or integers to binary with order reserved.

  ## Example

        iex> x = Sortable.encode(["foo", 99])
        <<31, 102, 111, 111, 0, 175>>
        iex> y = Sortable.encode(["foo", 1999])
        <<31, 102, 111, 111, 0, 205, 7, 207>>
        iex> x < y
        true

  """

  @spec encode(t) :: binary()

  def encode([]) do
    <<>>
  end

  def encode([first | rest]) do
    zero = :persistent_term.get(@zero_key)

    Enum.reduce(rest, encoding(first, zero), fn item, acc ->
      [acc | encoding(item, zero)]
    end)
    |> IO.iodata_to_binary()
  end

  @doc """

  Decode binary with Sortable format to list of binaries, floats or integers.

  ## Example

      iex> encoded = Sortable.encode(["foo", "bar", 123])
      <<31, 102, 111, 111, 0, 31, 98, 97, 114, 0, 199>>
      iex> Sortable.decode(encoded)
      ["foo", "bar", 123]

  """

  @spec decode(binary()) :: t

  def decode(data) when is_binary(data) do
    zero = :persistent_term.get(@zero_key)

    decoding(data, [], zero)
    |> Enum.reverse()
  end

  defp encoding(:min_binary, _zero) do
    [30]
  end

  defp encoding(b, zero) when is_binary(b) do
    case :binary.split(b, zero, [:global]) do
      [bin] ->
        [31, bin, 0]

      [bin_1, bin_2] ->
        [31, bin_1, <<0, 255>>, bin_2, 0]

      [bin_1, bin_2, bin_3] ->
        [31, bin_1, <<0, 255>>, bin_2, <<0, 255>>, bin_3, 0]

      [bin_1, bin_2, bin_3, bin_4] ->
        [31, bin_1, <<0, 255>>, bin_2, <<0, 255>>, bin_3, <<0, 255>>, bin_4, 0]

      bins ->
        [31, Enum.intersperse(bins, <<0, 255>>), 0]
    end
  end

  defp encoding(:max_binary, _zero) do
    [32]
  end

  defp encoding(:min_float, _zero) do
    [40]
  end

  defp encoding(f, _zero) when is_float(f) do
    cond do
      f < 0.0 ->
        <<i::64>> = <<f::float>>
        [41, <<i ^^^ 0xFFFFFFFFFFFFFFFF::64>>]

      f === 0.0 ->
        [42]

      true ->
        [43, <<f::float>>]
    end
  end

  defp encoding(:max_float, _zero) do
    [44]
  end

  defp encoding(:min_integer, _zero) do
    [50]
  end

  defp encoding(i, _zero) when is_integer(i) do
    cond do
      i < 0 ->
        encoded = complement(:binary.encode_unsigned(-i))
        code = 76 - byte_size(encoded)

        if code < 56 do
          # TODO: support neg-intger larger than 20 bytes
          raise ArgumentError, message: "integer too small"
        else
          [code, encoded]
        end

      i < 128 ->
        [i + 76]

      true ->
        encoded = :binary.encode_unsigned(i)
        code = byte_size(encoded) + 203

        if code > 223 do
          # TODO: support pos-integer larger than 20 bytes
          raise ArgumentError, message: "integer too big"
        else
          [code, encoded]
        end
    end
  end

  defp encoding(:max_integer, _zero) do
    [229]
  end

  defp decoding(<<>>, acc, _zero) do
    acc
  end

  defp decoding(<<30, rest::bits>>, acc, zero) do
    decoding(rest, [:min_binary | acc], zero)
  end

  defp decoding(<<31, data::bits>>, acc, zero) do
    decode_bin(data, [], acc, zero)
  end

  defp decoding(<<32, rest::bits>>, acc, zero) do
    decoding(rest, [:max_binary | acc], zero)
  end

  defp decoding(<<40, rest::bits>>, acc, zero) do
    decoding(rest, [:min_float | acc], zero)
  end

  # neg float
  defp decoding(<<41, b::64, rest::bits>>, acc, zero) do
    <<f::float>> = <<b ^^^ 0xFFFFFFFFFFFFFFFF::64>>
    decoding(rest, [f | acc], zero)
  end

  # 0.0
  defp decoding(<<42, rest::bits>>, acc, zero) do
    decoding(rest, [0.0 | acc], zero)
  end

  # pos float
  defp decoding(<<43, f::float, rest::bits>>, acc, zero) do
    decoding(rest, [f | acc], zero)
  end

  defp decoding(<<44, rest::bits>>, acc, zero) do
    decoding(rest, [:max_float | acc], zero)
  end

  defp decoding(<<50, rest::bits>>, acc, zero) do
    decoding(rest, [:min_integer | acc], zero)
  end

  # neg integer
  for code <- 56..75, size = (76 - code) * 8 do
    defp decoding(<<unquote(code), b::bits-size(unquote(size)), rest::bits>>, acc, zero) do
      <<int::unquote(size)>> = complement(b)
      decoding(rest, [-int | acc], zero)
    end
  end

  # for 0~127
  for code <- 76..203, num = code - 76 do
    defp decoding(<<unquote(code), rest::bits>>, acc, zero) do
      decoding(rest, [unquote(num) | acc], zero)
    end
  end

  # pos integer
  for code <- 204..228, size = (code - 203) * 8 do
    defp decoding(<<unquote(code), int::unquote(size), rest::bits>>, acc, zero) do
      decoding(rest, [int | acc], zero)
    end
  end

  defp decoding(<<229, rest::bits>>, acc, zero) do
    decoding(rest, [:max_integer | acc], zero)
  end

  defp concat_bins([], bin), do: bin
  defp concat_bins(bin_acc, bin), do: IO.iodata_to_binary([bin_acc, bin])

  defp decode_bin(<<data::bits>>, bin_acc, acc, zero) do
    case :binary.split(data, zero) do
      [bin, <<>>] ->
        [concat_bins(bin_acc, bin) | acc]

      [bin, <<255, rest::bits>>] ->
        decode_bin(rest, [bin_acc, bin, 0], acc, zero)

      [bin, <<rest::bits>>] ->
        decoding(rest, [concat_bins(bin_acc, bin) | acc], zero)
    end
  end

  # `decode_bin2` is faster in some cases, especially when binary
  # contains a lot <<0>>.
  #
  # TODO: compare `decode_bin` and `decode_bin2` when
  # https://github.com/erlang/otp/pull/1803 is released because
  # `:binary.split` might be highly optimised.

  # defp decode_bin2(<<0, 255, rest::bits>>, bin_acc, acc, zero) do
  #   decode_bin2(rest, [0 | bin_acc], acc, zero)
  # end

  # defp decode_bin2(<<0, rest::bits>>, bin_acc, acc, zero) do
  #   bin = :lists.reverse(bin_acc) |> :erlang.list_to_binary()
  #   decoding(rest, [bin | acc], zero)
  # end

  # defp decode_bin2(<<char, rest::bits>>, bin_acc, acc, zero) do
  #   decode_bin2(rest, [char | bin_acc], acc, zero)
  # end

  defp complement(<<>>), do: <<>>
  defp complement(<<i::8>>), do: <<i ^^^ 0xFF::8>>
  defp complement(<<i::16>>), do: <<i ^^^ 0xFFFF::16>>
  defp complement(<<i::24>>), do: <<i ^^^ 0xFFFFFF::24>>
  defp complement(<<i::32>>), do: <<i ^^^ 0xFFFFFFFF::32>>

  defp complement(<<i::32, rest::bits>>) do
    <<i ^^^ 0xFFFFFFFF::32, complement(rest)::bits>>
  end
end
