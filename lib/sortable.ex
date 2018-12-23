defmodule Sortable do
  @moduledoc """
  Documentation for Sortable.
  """

  use Bitwise

  # order:
  # :min_binary(1) < binary(2) < :max_binary(3) < :min_float(5) < float-neg(6) < float-non-neg(7) < :max_float(8) < :min_integer(10) < integer(12~251) < :max_integer(253)
  # 0, 4, 9, 11, 252, 254 are reserved for future extension

  @type items() :: [
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

  @spec encode(items()) :: binary()
  def encode(list) when is_list(list) do
    do_encode(list, <<0>>)
  end

  @spec decode(binary()) :: items()
  def decode(data) when is_binary(data) do
    do_decode(data, <<0>>)
  end

  @spec compile() :: {(items() -> binary()), (binary() -> items())}
  def compile() do
    compiled_zero = :binary.compile_pattern(<<0>>)

    encode = fn list when is_list(list) ->
      do_encode(list, compiled_zero)
    end

    decode = fn data when is_binary(data) ->
      do_decode(data, compiled_zero)
    end

    {encode, decode}
  end

  defp do_encode([], _zero), do: <<>>

  defp do_encode([first | rest], zero) do
    Enum.reduce(rest, encoding(first, zero), fn item, acc ->
      [acc | encoding(item, zero)]
    end)
    |> IO.iodata_to_binary()
  end

  defp encoding(:min_binary, _zero) do
    [1]
  end

  defp encoding(b, zero) when is_binary(b) do
    case :binary.split(b, zero, [:global]) do
      [bin] ->
        [2, bin, 0]

      [bin_1, bin_2] ->
        [2, bin_1, <<0, 255>>, bin_2, 0]

      [bin_1, bin_2, bin_3] ->
        [2, bin_1, <<0, 255>>, bin_2, <<0, 255>>, bin_3, 0]

      [bin_1, bin_2, bin_3, bin_4] ->
        [2, bin_1, <<0, 255>>, bin_2, <<0, 255>>, bin_3, <<0, 255>>, bin_4, 0]

      bins ->
        [2, Enum.intersperse(bins, <<0, 255>>), 0]
    end
  end

  defp encoding(:max_binary, _zero) do
    [3]
  end

  defp encoding(:min_float, _zero) do
    [5]
  end

  defp encoding(f, _zero) when is_float(f) do
    if f < 0 do
      <<i::64>> = <<f::float>>
      [6, <<i ^^^ 0xFFFFFFFFFFFFFFFF::64>>]
    else
      [7, <<f::float>>]
    end
  end

  defp encoding(:max_float, _zero) do
    [8]
  end

  defp encoding(:min_integer, _zero) do
    [10]
  end

  defp encoding(i, _zero) when is_integer(i) do
    if i < 0 do
      encoded = complement(:binary.encode_unsigned(-i))
      code = 132 - byte_size(encoded)

      if code < 12 do
        raise ArgumentError, message: "integer too small"
      end

      [code, encoded]
    else
      encoded = :binary.encode_unsigned(i)
      code = byte_size(encoded) + 131

      if code > 251 do
        raise ArgumentError, message: "integer too big"
      end

      [code, encoded]
    end
  end

  defp encoding(:max_integer, _zero) do
    [253]
  end

  defp do_decode(<<>>, _), do: []

  defp do_decode(data, zero) do
    decoding(data, [], zero)
    |> Enum.reverse()
  end

  defp decoding(<<>>, acc, _zero) do
    acc
  end

  defp decoding(<<1, rest::bits>>, acc, zero) do
    decoding(rest, [:min_binary | acc], zero)
  end

  defp decoding(<<2, data::bits>>, acc, zero) do
    decode_bin(data, [], acc, zero)
  end

  defp decoding(<<3, rest::bits>>, acc, zero) do
    decoding(rest, [:max_binary | acc], zero)
  end

  defp decoding(<<5, rest::bits>>, acc, zero) do
    decoding(rest, [:min_float | acc], zero)
  end

  # negative float
  defp decoding(<<6, b::64, rest::bits>>, acc, zero) do
    <<f::float>> = <<b ^^^ 0xFFFFFFFFFFFFFFFF::64>>
    decoding(rest, [f | acc], zero)
  end

  # non-negative float
  defp decoding(<<7, f::float, rest::bits>>, acc, zero) do
    decoding(rest, [f | acc], zero)
  end

  defp decoding(<<8, rest::bits>>, acc, zero) do
    decoding(rest, [:max_float | acc], zero)
  end

  defp decoding(<<10, rest::bits>>, acc, zero) do
    decoding(rest, [:min_integer | acc], zero)
  end

  # negative integer
  for code <- 12..131, size = (132 - code) * 8 do
    defp decoding(<<unquote(code), b::bits-size(unquote(size)), rest::bits>>, acc, zero) do
      <<int::unquote(size)>> = complement(b)
      decoding(rest, [-int | acc], zero)
    end
  end

  # non-negative integer
  for code <- 132..251, size = (code - 131) * 8 do
    defp decoding(<<unquote(code), int::unquote(size), rest::bits>>, acc, zero) do
      decoding(rest, [int | acc], zero)
    end
  end

  defp decoding(<<253, rest::bits>>, acc, zero) do
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
