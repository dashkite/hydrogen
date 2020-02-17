import {pipe, tee, rtee, curry} from "panda-garden"
import {cat, properties, titleCase, plainText,
  promise, all, isFunction} from "panda-parchment"
import Store from "./store"

mix = (type, mixins) -> (pipe mixins...) type

getter = getters = curry rtee (dictionary, T) ->
  for key, fn of dictionary
    properties T::, [key]: get: fn

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
  T.create = (value) ->
    (new @).initialize value
  T::initialize = ({@source, @reference, @bindings}) ->
    initialize @, T.initializers
  mix T, [
    getters
      name: -> @reference.name
      path: -> @reference.path
      link: -> @path
      parent: -> @reference.parent
    index "name"
    index "path"
  ]

ready = curry rtee (f, T) -> (T.initializers ?= []).push f

index = curry rtee (name, T) ->
  # self is a promise for this
  mix T, [
    ready (self) ->
      Store.add @store,
        index: name
        key: @[name]
        value: self
      # explicitly return undefined to avoid awaiting
      undefined
  ]

title = tee (T) ->
  mix T, [
    getter title: -> @data?.title ? titleCase plainText @name
    index "title" ]

data = (load) -> getter data: -> load @

# TODO is this the best interface?
# TODO make async-maybe use a ready handler?
content = (load) -> getter html: -> load @

summary = getter summary: -> @data.summary

route = curry rtee (template, T) ->
  Store.map T.store, {template, handler: -> T.create arguments...}

store = curry rtee (s, T) ->
  properties T, store: get: -> s
  properties T::, store: get: -> s

# not a mixin, but used with mixins that take loaders-a loader combinator
loaders = (fx) -> ->
  for f in fx
    if (result = f arguments...)?
      break
  result

export {mix, getter, getters, basic, ready, index,
  data, title, content, summary,
  route, store, loaders}
