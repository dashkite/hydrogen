import {pipe, tee, rtee, curry} from "panda-garden"
import {cat, properties, titleCase, promise, all, isFunction} from "panda-parchment"
import {add, map} from "./store"

mix = (type, mixins) -> (pipe mixins...) type

warrant = ->
  _ = {}
  _.promise = promise (resolve, reject) ->
    _.resolve = resolve
    _.reject = reject
  _

initialize = (instance, initializers) ->
  _ = warrant()
  try
    if initializers?
      await all do ->
        for initializer in initializers
          initializer.call instance, _.promise
    _.resolve  instance
  catch error
    _.reject error
  instance

basic = tee (T) ->
  T.create = (value) -> (new T).initialize value
  T::initialize = ({@store, @source, @reference, @bindings}) ->
    initialize @, T.initializers
  properties T::,
    name: get: -> @reference.name
    path: get: -> @reference.path
    link: get: -> @path
    parent: get: -> @reference.parent
  mix T, [
    index "name"
    index "path"
  ]

ready = curry rtee (f, T) -> (T.initializers ?= []).push f

index = curry rtee (name, T) ->
  # self is a promise for this
  mix T, [
    ready (self) ->
      add @store,
        index: name
        key: @[name]
        value: self
      # explicitly return undefined to avoid awaiting
      undefined
  ]

title = tee (T) ->
  properties T::,
    title: get: -> @data?.title ? titleCase @name
  mix T, [ index "title" ]

data = curry rtee (load, T) ->
  properties T::,
    data: get: -> load @

# TODO is this the best interface?
# TODO make async
content = curry rtee (load, T) ->
  properties T::,
    html: get: -> load @

summary = tee (T) ->
  properties T::,
    summary: get: -> @data.summary

route = curry rtee (template, T) -> map template, T.create

store = curry rtee (s, T) ->
  properties T, store: get: -> s
  properties T::, store: get: -> s

# not a mixin, but used with mixins that take loaders-a loader combinator
loaders = (fx) ->
  (args...) ->
    for f in fx
      if (result = f args...)?
        break
    result

export {mix, basic, ready, index, data, title, content, summary,
  route, store, loaders}
