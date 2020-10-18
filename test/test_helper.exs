# Load Nebulex helper
for file <- File.ls!("deps/nebulex/test/support"), file != "test_cache.ex" do
  Code.require_file("../deps/nebulex/test/support/" <> file, __DIR__)
end

for file <- File.ls!("deps/nebulex/test/shared/cache") do
  Code.require_file("../deps/nebulex/test/shared/cache/" <> file, __DIR__)
end

for file <- File.ls!("deps/nebulex/test/shared"), file != "cache" do
  Code.require_file("../deps/nebulex/test/shared/" <> file, __DIR__)
end

# Load shared tests
for file <- File.ls!("test/shared/cache") do
  Code.require_file("./shared/cache/" <> file, __DIR__)
end

for file <- File.ls!("test/shared"), not File.dir?("test/shared/" <> file) do
  Code.require_file("./shared/" <> file, __DIR__)
end

ExUnit.start()
