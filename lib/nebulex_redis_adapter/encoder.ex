defmodule NebulexRedisAdapter.Encoder do
  @moduledoc false

  alias Nebulex.Object

  @type dt :: :object | :string

  @spec encode(term, dt) :: binary
  def encode(data, dt \\ :object)

  def encode(%Object{value: data}, :string) do
    to_string(data)
  end

  def encode(data, :compressed) do
    :erlang.term_to_binary(data, [:compressed])
  end

  def encode(data, _) do
    to_string(data)
  rescue
    _e -> :erlang.term_to_binary(data)
  end

  @spec decode(binary | nil) :: term
  def decode(nil), do: nil

  def decode(data) do
    if String.printable?(data) do
      data
    else
      :erlang.binary_to_term(data)
    end
  end
end
