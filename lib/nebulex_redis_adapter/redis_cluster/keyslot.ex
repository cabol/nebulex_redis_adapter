defmodule NebulexRedisAdapter.RedisCluster.Keyslot do
  @moduledoc """
  Default `Nebulex.Adapter.Keyslot` implementation.
  """

  use Nebulex.Adapter.Keyslot

  if Code.ensure_loaded?(CRC) do
    alias NebulexRedisAdapter.Serializer.Serializable

    @impl true
    def hash_slot(key, range)

    def hash_slot(key, range) when is_binary(key) do
      key
      |> compute_key()
      |> do_hash_slot(range)
    end

    def hash_slot(key, range) do
      key
      |> Serializable.encode()
      |> do_hash_slot(range)
    end

    defp do_hash_slot(key, range) do
      :crc_16_xmodem
      |> CRC.crc(key)
      |> rem(range)
    end
  end

  @doc """
  Helper function to compute the key; regardless the key contains hashtags
  or not.
  """
  @spec compute_key(binary()) :: binary()
  def compute_key(key) when is_binary(key) do
    _ignore =
      for <<c <- key>>, reduce: nil do
        nil -> if c == ?{, do: []
        acc -> if c == ?}, do: throw({:hashtag, acc}), else: [c | acc]
      end

    key
  catch
    {:hashtag, []} ->
      key

    {:hashtag, ht} ->
      ht
      |> Enum.reverse()
      |> IO.iodata_to_binary()
  end
end
