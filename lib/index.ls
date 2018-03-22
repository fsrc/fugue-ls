require! \prelude-ls : { keys, each }

prelude = require(\prelude-ls)
fugue   = require(\./fugue)

module.exports = {}

# Copy prelude onto export
prelude
|> keys
|> each (key) -> module.exports[key] = prelude[key]

# Copy fugue onto export
fugue
|> keys
|> each (key) -> module.exports[key] = fugue[key]

