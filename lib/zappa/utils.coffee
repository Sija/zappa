coffeescript_support = """
  var __slice = Array.prototype.slice;
  var __hasProp = Object.prototype.hasOwnProperty;
  var __bind = function(fn, me) { return function() { return fn.apply(me, arguments); }; };
  var __extends = function(child, parent) {
    for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype;
    return child;
  };
  var __indexOf = Array.prototype.indexOf || function(item) {
    for (var i = 0, l = this.length; i < l; i++) {
      if (this[i] === item) return i;
    }
    return -1;
  };
"""

build_msg = (title, data) ->
  obj = {}
  obj[title] = data
  JSON.stringify(obj)

parse_msg = (raw_msg) ->
  obj = JSON.parse(raw_msg)
  for k, v of obj
    return { title: k, params: v }

scoped = (code) ->
  code = String(code)
  code = "function () { #{code} }" unless code.indexOf('function') is 0
  code = "#{coffeescript_support} with(locals) { return (#{code}).apply(context, args); }"
  new Function('context', 'locals', 'args', code)

publish_api = (from, to, methods) ->
  for name in methods.split '|'
    do (name) ->
      if typeof from[name] is 'function'
        to[name] = -> from[name].apply from, arguments
      else
        to[name] = from[name]

extend = (src, objects...) ->
  for object in objects
    for key of object
      src[key] = object[key] if Object::hasOwnProperty.call object, key
  src

exports[func] = eval func for func in 'build_msg|parse_msg|scoped|publish_api|extend'.split '|'
