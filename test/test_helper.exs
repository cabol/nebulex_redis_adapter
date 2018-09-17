# Load support files
support_files =
  for file <- File.ls!("test/support") do
    {file, Code.require_file("support/" <> file, __DIR__)}
  end

# Load shared tests
for file <- File.ls!("test/shared"), not File.dir?("test/shared/" <> file) do
  Code.require_file("./shared/" <> file, __DIR__)
end

# Load Nebulex helper
File.cd!("deps/nebulex", fn ->
  Code.require_file("test/test_helper.exs")
end)

# Load support files on remote nodes if clustered is present
unless :clustered in Keyword.get(ExUnit.configuration(), :exclude, []) do
  nodes = Node.list()

  Enum.each(support_files, fn {file, loaded} ->
    Enum.each(loaded, fn {mod, bin} ->
      expected = List.duplicate({:module, mod}, length(nodes))

      {^expected, []} =
        :rpc.multicall(
          nodes,
          :code,
          :load_binary,
          [mod, to_charlist(file), bin]
        )
    end)
  end)
end

ExUnit.start()
