defprotocol NebulexRedisAdapter.Codec.StringProto do
  @moduledoc """
  Protocol controlling how a key/value is encoded to a string
  and how a string is decoded into an Elixir term.

  See [Redis Strings](https://redis.io/docs/data-types/strings/).
  """

  @fallback_to_any true

  @doc """
  Encodes `data` with the given `opts`.
  """
  @spec encode(term, [term]) :: binary
  def encode(data, opts \\ [])

  @doc """
  Decodes `data` with the given `opts`.
  """
  @spec decode(binary, [term]) :: term
  def decode(data, opts \\ [])
end

defimpl NebulexRedisAdapter.Codec.StringProto, for: BitString do
  def encode(binary, _opts) when is_binary(binary) do
    binary
  end

  def encode(bitstring, _opts) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: bitstring,
      description: "cannot encode a bitstring to a string"
  end

  def decode(data, _opts) do
    if not is_nil(data) do
      :erlang.binary_to_term(data)
    end
  rescue
    ArgumentError -> data
  end
end

defimpl NebulexRedisAdapter.Codec.StringProto, for: Any do
  def encode(data, opts) do
    opts = Keyword.take(opts, [:compressed, :minor_version])

    :erlang.term_to_binary(data, opts)
  end

  def decode(data, _opts) do
    data
  end
end
