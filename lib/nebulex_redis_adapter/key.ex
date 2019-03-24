defmodule NebulexRedisAdapter.Key do
  @moduledoc false

  @spec encode(term) :: binary
  def encode(data) do
    to_string(data)
  rescue
    _e -> :erlang.term_to_binary(data)
  end

  @spec encode(binary | nil) :: term
  def decode(nil), do: nil

  def decode(data) do
    if String.printable?(data) do
      data
    else
      :erlang.binary_to_term(data)
    end
  end
end
