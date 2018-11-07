# Load support files
for dir <- ["support", "shared"], file <- File.ls!("test/" <> dir) do
  Code.require_file(dir <> "/" <> file, __DIR__)
end

# Load Nebulex helper
File.cd!("deps/nebulex", fn ->
  Code.require_file("test/test_helper.exs")
end)

ExUnit.start()
