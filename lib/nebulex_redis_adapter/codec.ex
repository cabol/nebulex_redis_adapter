defmodule NebulexRedisAdapter.Codec do
  @moduledoc """
  A **Codec** encodes keys and values sent to Redis,
  and decodes keys and values in the command output.

  See [Redis Strings](https://redis.io/docs/data-types/strings/).
  """

  @doc """
  Encodes `key` with the given `opts`.
  """
  @callback encode_key(key :: term, opts :: [term]) :: iodata

  @doc """
  Encodes `value` with the given `opts`.
  """
  @callback encode_value(value :: term, opts :: [term]) :: iodata

  @doc """
  Decodes `key` with the given `opts`.
  """
  @callback decode_key(key :: binary, opts :: [term]) :: term

  @doc """
  Decodes `value` with the given `opts`.
  """
  @callback decode_value(value :: binary, opts :: [term]) :: term

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour NebulexRedisAdapter.Codec

      alias NebulexRedisAdapter.Codec.StringProto

      @impl true
      defdelegate encode_key(key, opts \\ []), to: StringProto, as: :encode

      @impl true
      defdelegate encode_value(value, opts \\ []), to: StringProto, as: :encode

      @impl true
      defdelegate decode_key(key, opts \\ []), to: StringProto, as: :decode

      @impl true
      defdelegate decode_value(value, opts \\ []), to: StringProto, as: :decode

      # Overridable callbacks
      defoverridable encode_key: 2, encode_value: 2, decode_key: 2, decode_value: 2
    end
  end
end
