import minimatch from "minimatch"
import {reduce} from "panda-river-esm"
import {first, last, rest, split, keys, all,
  isString, isArray, isType} from "panda-parchment"
import Method from "panda-generics"
import {binary, curry} from "panda-garden"
import {Router} from "panda-router"

# untility methods for parsing paths

join = (c, ax) -> ax.join c

drop = ([ax..., a]) -> ax

normalize = (components) ->
  name = first split ".", last components
  if components.length > 1
    parent = "/" + join "/", drop components
    path = join "/", [ parent, name ]
  else
    parent = "/"
    path = "/" + name
  {path, parent, name}

parse = (path) ->
  # ignore the initial .
  components = rest split "/", path
  source = normalize components
  if source.name == "index"
    reference = normalize drop components
  else
    reference = source
  {source, reference}

class Store
  @create: -> new Store arguments...
  constructor: ({@indices = {}, @router = new Router}) ->

create = -> Store.create arguments...

map = curry tee (store, {template, handler}) ->
  store.router.add {template, data: {handler}}

match = curry (store, path) ->
  if (m = store.router.match path)?
    {bindings, data: {handler}} = m
    {bindings, handler}

# TODO support URLs

load = Method.create
  name: "load"
  description: "Load a resource into a Hydrogen store"

Method.define load, (isType Store), isString, (store, path) ->
  {source, reference} = parse path
  if (m = match store, reference.path)?
    {handler, bindings} = m
    handler {store, source, reference, bindings}

Method.define load, (isType Store), isArray, (store, paths) ->
  all resource store, path for path in paths

load = curry binary load

add = curry (store, {index, key, value}) -> (store.indices[index] ?= {})[key] = value

lookup = curry (store, {index, key}) ->
  await store.indices[index]?[key]

find = curry (store, key) ->
  for name, index of store.indices
    return await value if (value = index[key])?
  # explicit return avoids implicit return of array of nulls
  undefined

glob = curry (store, pattern) ->
  if (dictionary = store.indices.path)?
    paths = minimatch.match (keys dictionary), pattern
    await all (dictionary[path] for path in paths)

# async replace
replace = (string, re, callback) ->
  do ({f, result} = {}, offset = 0) ->

    # define a function that takes a match from matchAll
    # and a string and performs the replacement
    # must be defined as a closure on callback and offset
    f = (string, result) ->
      do ({match, index, groups} = {}) ->
        # 1. obtain the replacement string
        {index} = result
        [match, groups...] = result
        replacement = await callback match, groups...
        # 2. figure out where to splice it in
        start = index + offset
        finish = start + match.length
        # 3. update the offset, which must happen after (2)
        offset += replacement.length - match.length
        # 4. generate the new string
        "#{string[0...start]}\
         #{replacement}\
         #{string[finish...]}"

    # loop through matches and do the replacements
    # TODO reduce doesn't wait on the transform so we have to use a loop
    for result from string.matchAll re
      string = await f string, result
    # return the final string
    string

links = curry (store, html) ->
  replace html, /\[([^\]]+)\]\[([^\]]+)?\]/g, (match, innerHTML, key) ->
    key ?= innerHTML.replace /<[^>]+>/g, ""
    if (target = await find store, key)?
      "<a href='#{target.link}'>#{innerHTML}</a>"
    else
      console.warn "Link [#{key}] not found."
      "<a href='#broken'>#{innerHTML}</a>"

export {map, match, load, add, lookup, find, glob, links}
