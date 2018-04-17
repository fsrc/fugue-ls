require! \prelude-ls : {
  drop
  take
  fold
  is-type
  keys
  map
  first
  tail
  apply
  values
  last
  camelize
  repeat

  split
  join
  }
require! \async-ls : {
  callbacks: {
    serial-map
    parallel-limited-filter
    parallel-map-limited
    }
  }

require! \util : { print }
require! \chalk : {
  blue: as-array
  red: as-string
  green: as-function
  yellow: as-key
  blue: as-argument
}
require! \string_decoder : { StringDecoder }

export acc = (initial, apply) ->
  accumulated = initial
  ->
    if accumulated == null
    then accumulated := it
    else if it?
    then accumulated := apply(accumulated, it)
    else {} <<< accumulated

export acc-obj = ->
  acc {}, (accumulated, obj) -> accumulated <<< obj


export count-if = (fn, list) -->
  list |> fold((acc, itm) ->
    if fn(itm)
    then acc + 1
    else acc
    )(0)


export map-bool = (pred, truthy, falsy, list) -->
  list |> map (itm) ->
    if pred(itm)
    then truthy(itm)
    else falsy(itm)

export pl-map = (threads, iterator, summarizer, list) -->
  parallel-map-limited(
    threads
    iterator
    list
    summarizer
    )

export pl-filter = (threads, iterator, summarizer, list) -->
  parallel-limited-filter(
    threads
    iterator
    list
    summarizer)

export put = (...) ->
  process.stdout.write((arguments |> values |> join(', ')))

export say = (...) ->
  console.log(...)
  arguments
  |> values
  |> last

export debug = (...) ->
  console.error(...)
  arguments
  |> values
  |> last

export chunkup = (length, fn, data) -->
  do ->
    source = data
    while source.length > 0
      fn( source |> take length )
      source := source |> drop length

export dechunk = (fn) ->
  do ->
    decoder = new StringDecoder \utf8
    last-string = ""
    (chunk) -> last-string := fn(last-string + decoder.write(chunk))
# pray = say
pray = -> it

export stack = (v) ->
  do ->
    state = []
    state.push v if v?

    inspect: -> state
    push:    -> pray \push, it; state.push it
    pop:     -> pray \pop,  state[state.length - 1]; state.pop!
    prev:    -> pray \peek, state[state.length - 2]; state[state.length - 2]
    peek:    -> state[state.length - 1]

export itr = (amount, fn) ->
  position = 1
  res: ~> position := 1
  dec: ~>
    while position > 0
      position := position - 1
      it = fn(it)

export whi = (acc, fn, acc2, fn2) ->
  while acc
    acc = fn(acc)
    acc2 = fn2(acc2)

export replace = (a, b, str) --> str.replace(a, b)

export sleep = (seconds) ->
  e = new Date!.getTime! + (seconds * 1000)

  while new Date!.getTime! <= e
    void

export counter = (stop, skip = 0) ->
  i = 0
  (fn) ->
    say "#i-- #{fn(i)}" if fn? and i > skip
    i += 1
    process.exit 4 if stop? and i == stop
    i

export indent = (str, indent-amount) -->
  str.to-string!
  |> split(/\n/g)
  |> map (line) -> "#{' ' * indent-amount}#line"
  |> join('\n')

inspect-leaf = (itm) ->
  (itm |> is-type 'String') or (itm |> is-type 'Function')

export inspect-str = (str, indent-amount = 2, level = 0) ->
  say indent(as-string(str), level)

export inspect-fun = (fun, indent-amount = 2, level = 0) ->
  fun-str = fun.to-string!
  head = fun-str
  |> split \\n
  |> first
  |> replace 'function ', ''
  |> replace /[\{|\}|\(|\)]/g, ''
  |> split ', '
  |> join as-function(', ')

  say indent(as-function("(#{as-argument(head)}) -> ..."), level)

export inspect-arr = (arr, indent-amount = 2, level = 0) ->
  # say as-array(\[)
  arr |> map (itm) ->
    put indent(as-array('*'), level)
    inspect itm, indent-amount, 1
  # say indent as-array(\]), level

export inspect-obj = (obj, indent-amount = 2, level = 0) ->
  obj
  |> keys
  |> map (key) ->
    if inspect-leaf obj[key]
      put as-key "#{indent(key, level)}:"
      actual-indent = 1
    else
      say as-key "#{indent(key, level)}:"
      actual-indent = level + indent-amount

    inspect obj[key], indent-amount, actual-indent

export inspect = (itm, indent-amount = 2, level = 0) ->
  if itm |> is-type 'Object'
  then inspect-obj itm, indent-amount, level
  else if itm |> is-type 'String'
  then inspect-str itm, indent-amount, level
  else if itm |> is-type 'Array'
  then inspect-arr itm, indent-amount, level
  else if itm |> is-type 'Function'
  then inspect-fun itm, indent-amount, level
  else inspect-str itm.to-string!, indent-amount, level


export promise = (fn) ->
  # Define the private object
  priv =
    state:
      on-error: null
      on-next : []
      on-finaly  : null
    fun: {}

  # Create the public interface that should be passed
  # back to the user of the promise
  pub = {}


  # Define next function
  priv.fun.next = ->
    next-fn = first priv.state.on-next
    priv.state.on-next = tail priv.state.on-next
    if next-fn?
    then apply(next-fn.fn, values(next-fn.args))
    else priv.state.on-finaly! if priv.state.on-finaly?

  # Define fail function
  priv.fun.fail = (err) ->
    priv.state.on-error(err) if priv.state.on-error
    priv.state.on-next = []

  priv.fun.nerr = (fn) ->
    (err, result) ->
      if err?
        priv.fail(err)
      else
        fn(result)

  priv.fun.event = (name) ->
    key = if name |> is-type 'String'
    then name
    else if name |> is-type 'Object'
    then keys(name).0

    priv.fun[key] = ->
    pub[key] = (fn) ->
      priv.fun[key] = fn
      pub


  # Define static functionality error and finaly
  pub.error = (fn) ->
    priv.state.on-error = fn
    pub

  pub.finaly = (fn) ->
    priv.state.on-finaly = fn
    priv.next!
    pub

  # Create a constructor of the object by preloading the object
  # with fail and next functions
  constr = fn(priv.fun)

  # Return a function that takes any number of arguments
  (...) ->
    # Pass the arguments to the constructor and get an object with functions
    obj = constr(...)

    obj
    # All function names
    |> keys
    |> map (key) ->
      # Copy a wrapped version of the function to the public interface
      pub[key] = (...) ->
        priv.state.on-next.push(fn:obj[key], args:arguments)
        pub

    pub

export decimals = ->
  return 0 if(Math.floor(it) == it)

  it.toString().split(".")[1].length || 0

export pad-char-left = (char, len, str) -->
  (repeat(len, char) + str).slice(-len);

export pad-char-right = (char, len, str) -->
  (str + repeat(len, char)).substring(0, len);

export pad-left = (str, len) ->
  (repeat(len, " ") + str).slice(-len);

export pad-right = (str, len) ->
  (str + repeat(len, " ")).substring(0, len);

export pad = pad-left

format-csv-string = (value) ->
  if is-type('String', value)
  then '"'+value+'"'
  else pad-left(value.to-string!replace('.', ','), 12)

export format-csv = fold((acc, value) ->
  acc =  keys(value).join("\t") + "\n" if not acc?
  acc += map(format-csv-string, values(value)).join("\t") + "\n"
  acc
, null)
