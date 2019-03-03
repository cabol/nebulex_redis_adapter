defmodule NebulexRedisAdapter.Cluster.HashSlot do
  @moduledoc """
  Hash Slot Interface.
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour NebulexRedisAdapter.Cluster.HashSlot

      @redis_cluster_hash_slots 16_384

      @doc false
      def compute("{" <> hash_tags = key) do
        case String.split(hash_tags, "}") do
          [key, _] -> do_compute(key)
          _ -> do_compute(key)
        end
      end

      def compute(key), do: do_compute(key)

      defp do_compute(key) do
        :crc_16_xmodem
        |> CRC.crc(key)
        |> rem(@redis_cluster_hash_slots)
      end

      defoverridable compute: 1
    end
  end

  @doc """
  Return the hash slot from the key..

  ## Example

      iex> MyHashSlot.compute("mykey")
      14687
  """
  @callback compute(key :: binary) :: non_neg_integer
end
