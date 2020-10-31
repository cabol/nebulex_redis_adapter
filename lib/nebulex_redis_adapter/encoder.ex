defmodule NebulexRedisAdapter.Encoder do
  @moduledoc false

  ## API

  @spec encode(term, Keyword.t()) :: binary
  def encode(data, opts \\ [])

  def encode(data, _opts) when is_binary(data) do
    data
  end

  def encode(data, opts) do
    opts = Keyword.take(opts, [:compressed, :minor_version])
    :erlang.term_to_binary(data, opts)
  end

  @spec decode(binary | nil) :: term
  def decode(nil), do: nil

  def decode(data) do
    :erlang.binary_to_term(data)
  rescue
    ArgumentError -> data
  end
end
