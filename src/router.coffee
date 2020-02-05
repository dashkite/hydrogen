import {Router} from "panda-router"

router = new Router()

route = (template, handler) ->
  router.add {template, data: {handler}}
  router

match = (path) ->
  if (m = router.match path)?
    {bindings, data: {handler}} = m
    {bindings, handler}


export {router, route, match}
