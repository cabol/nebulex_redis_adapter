if Code.ensure_loaded?(CRC) do
  defmodule NebulexRedisAdapter.RedisCluster.Keyslot do
    @moduledoc false
    use Nebulex.Adapter.Keyslot

    alias NebulexRedisAdapter.Serializer.Serializable

    @impl true
    def hash_slot("{" <> hash_tags = key, range) do
      case String.split(hash_tags, "}") do
        [key, _] -> do_hash_slot(key, range)
        _ -> do_hash_slot(key, range)
      end
    end

    def hash_slot(key, range) when is_binary(key) do
      do_hash_slot(key, range)
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
else
  defmodule NebulexRedisAdapter.RedisCluster.Keyslot do
    @moduledoc false
    use Nebulex.Adapter.Keyslot
  end
end
