defmodule Sortable do
  @moduledoc """
  Documentation for Sortable.
  """

  # code:
  # 0 to 126 is negative
  # 127 to 253 is non-negative
  # 254 is binary

  @spec encode([binary | integer]) :: binary
  def encode(list) when is_list(list) do
    do_encode(list, <<0>>)
  end

  @spec decode(binary()) :: [binary | integer]
  def decode(data) when is_binary(data) do
    do_decode(data, <<0>>)
  end

  @spec compile() :: {([binary | integer] -> binary), (binary -> [binary | integer])}
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
      [acc, 0 | encoding(item, zero)]
    end)
    |> IO.iodata_to_binary()
  end

  defp encoding(b, zero) when is_binary(b) do
    [254, :binary.replace(b, zero, <<0, 255>>, [:global])]
  end

  defp encoding(i, _zero) when is_integer(i) do
    if i >= 0 do
      encoded = :binary.encode_unsigned(i)
      code = byte_size(encoded) + 126

      if code > 253 do
        raise ArgumentError, message: "int too big"
      end

      [code, encoded]
    else
      encoded = complement(:binary.encode_unsigned(-i))
      code = 127 - byte_size(encoded)

      if code < 0 do
        raise ArgumentError, message: "int too small"
      end

      [code, encoded]
    end
  end

  defp do_decode(<<>>, _), do: []

  defp do_decode(<<code, data::binary>>, zero) do
    decoding(code, data, [], zero)
    |> Enum.reverse()
  end

  defp concat_bins(bin, []) do
    bin
  end

  defp concat_bins(bin, acc) do
    Enum.reverse([bin | acc]) |> IO.iodata_to_binary()
  end

  defp split_binary(data, acc, zero) do
    case :binary.split(data, zero) do
      [bin] ->
        {concat_bins(bin, acc), <<>>}

      [bin, <<255, rest::binary>>] ->
        split_binary(rest, [0, bin | acc], zero)

      [bin, rest] ->
        {concat_bins(bin, acc), rest}
    end
  end

  defp decoding(254, data, acc, zero) do
    case split_binary(data, [], zero) do
      {bin, <<>>} ->
        [bin | acc]

      {bin, <<next_code, next_data::binary>>} ->
        decoding(next_code, next_data, [bin | acc], zero)
    end
  end

  # parse negative integer
  defp decoding(code, data, acc, zero) when code <= 126 do
    int_size = 127 - code
    data_size = byte_size(data)

    int =
      binary_part(data, 0, int_size)
      |> decode_neg()

    if data_size > int_size do
      next_code = :binary.at(data, int_size + 1)
      next_data = binary_part(data, int_size + 2, data_size - int_size - 2)
      decoding(next_code, next_data, [int | acc], zero)
    else
      [int | acc]
    end
  end

  # parse non_negative integer
  defp decoding(code, data, acc, zero) when code <= 253 do
    int_size = code - 126
    data_size = byte_size(data)

    int = :binary.decode_unsigned(binary_part(data, 0, int_size))

    if data_size > int_size do
      next_code = :binary.at(data, int_size + 1)
      next_data = binary_part(data, int_size + 2, data_size - int_size - 2)
      decoding(next_code, next_data, [int | acc], zero)
    else
      [int | acc]
    end
  end

  defp decode_neg(<<a>>), do: a - 255
  defp decode_neg(<<a, b>>), do: (a - 255) * 256 + (b - 255)
  defp decode_neg(<<a, b, c>>), do: (a - 255) * 65536 + (b - 255) * 256 + (c - 255)

  defp decode_neg(bin) do
    bin
    |> complement()
    |> :binary.decode_unsigned()
    |> Kernel.-()
  end

  defp complement(<<>>), do: <<>>
  defp complement(<<a>>), do: <<255 - a>>
  defp complement(<<a, b>>), do: <<255 - a, 255 - b>>
  defp complement(<<a, b, c>>), do: <<255 - a, 255 - b, 255 - c>>

  defp complement(<<n, rest::binary>>) do
    <<255 - n, complement(rest)::binary>>
  end
end
