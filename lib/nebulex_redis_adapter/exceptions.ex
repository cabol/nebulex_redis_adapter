defmodule NebulexRedisAdapter.Error do
  @moduledoc """
  NebulexRedisAdapter error.
  """

  @typedoc "Error reason type"
  @type reason :: :atom | {:atom, term}

  @typedoc "Error type"
  @type t :: %__MODULE__{reason: reason, cache: atom}

  # Exception struct
  defexception reason: nil, cache: nil

  ## API

  @doc false
  def exception(opts) do
    reason = Keyword.fetch!(opts, :reason)
    cache = Keyword.fetch!(opts, :cache)

    %__MODULE__{reason: reason, cache: cache}
  end

  @doc false
  def message(%__MODULE__{reason: reason, cache: cache}) do
    format_error(reason, cache)
  end

  ## Helpers

  def format_error(:redis_cluster_status_error, cache) do
    "Could not run the command because Redis Cluster is in error status " <>
      "for cache #{inspect(cache)}."
  end

  def format_error({:redis_cluster_setup_error, reason}, cache) when is_exception(reason) do
    "Could not setup Redis Cluster for cache #{inspect(cache)}. " <> Exception.message(reason)
  end

  def format_error({:redis_cluster_setup_error, reason}, cache) do
    "Could not setup Redis Cluster for cache #{inspect(cache)}. " <>
      "Failed with error #{inspect(reason)}."
  end
end
