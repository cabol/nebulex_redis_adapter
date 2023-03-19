defmodule NebulexRedisAdapter.Helpers do
  @moduledoc false

  import Bitwise, only: [<<<: 2]

  # Inline common instructions
  @compile {:inline, redis_command_opts: 1}

  ## API

  @spec redis_command_opts(Keyword.t()) :: Keyword.t()
  def redis_command_opts(opts) do
    Keyword.take(opts, [:timeout, :telemetry_metadata])
  end

  @spec random_sleep(pos_integer) :: :ok
  def random_sleep(times) do
    t = random_timeout(times)

    receive do
    after
      t -> :ok
    end
  end

  @spec random_timeout(pos_integer) :: pos_integer
  def random_timeout(times) do
    _ = if rem(times, 10) == 0, do: :rand.seed(:exsplus)

    # First time 1/4 seconds, then doubling each time up to 8 seconds max
    tmax =
      if times > 5 do
        8000
      else
        div((1 <<< times) * 1000, 8)
      end

    :rand.uniform(tmax)
  end

  @doc false
  defmacro wrap_error(exception, opts) do
    quote do
      {:error, unquote(exception).exception(unquote(opts))}
    end
  end
end
