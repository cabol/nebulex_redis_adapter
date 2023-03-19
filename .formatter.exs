locals_without_parens = [
  # Helpers
  wrap_error: 1,
  wrap_error: 2
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 100,
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
