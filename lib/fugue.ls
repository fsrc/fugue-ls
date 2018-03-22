require! \prelude-ls : {
  fold
  is-type
  keys
  map
  first
  tail
  apply
  values
  last

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

  # Define next function
  priv.next = ->
    next-fn = first priv.state.on-next
    priv.state.on-next = tail priv.state.on-next
    if next-fn?
    then apply(next-fn.fn, values(next-fn.args))
    else priv.state.on-finaly! if priv.state.on-finaly?

  # Define fail function
  priv.fail = (err) ->
    priv.state.on-error(err) if priv.state.on-error
    priv.state.on-next = []

  priv.nerr = (fn) ->
    (err, result) ->
      if err?
        priv.fail(err)
      else
        fn(result)

  # Create the public interface that should be passed
  # back to the user of the promise
  pub = {}

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
  constr = fn(priv.fail, priv.next, priv.nerr)

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
