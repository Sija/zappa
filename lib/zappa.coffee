zappa = exports
fs = require 'fs'
puts = console.log
{inspect} = require 'sys'
coffee = null

{App} = require './app'
{scoped} = require './utils'

class Zappa
  constructor: ->
    @context = {}
    @apps = {}
    @current_app = null

    @locals =
      app: (name, server) => @app name, server
      include: (path) => @include path
      require: require
      global: global
      process: process
      module: module

    for name in 'get|post|put|del|route|at|msg|client|using|def|helper|postrender|layout|view|style'.split '|'
      do (name) =>
        @locals[name] = =>
          @ensure_app 'default' unless @current_app?
          @current_app[name].apply @current_app, arguments

  app: (name, server) ->
    @ensure_app name, server
    @current_app = @apps[name]

  include: (file) ->
    @define_with @read_and_compile(file)
    puts "Included file \"#{file}\""

  define_with: (code) ->
    scoped(code)(@context, @locals)

  ensure_app: (name, server) ->
    @apps[name] = new App(name, server) unless @apps[name]?
    @current_app = @apps[name] unless @current_app?

  read_and_compile: (file) ->
    coffee = require 'coffee-script'
    code = @read file
    coffee.compile code

  read: (file) -> fs.readFileSync file, 'utf8'

  run_file: (file, options) ->
    @locals.__filename = require('path').join(process.cwd(), file)
    @locals.__dirname = process.cwd()
    @locals.module.filename = @locals.__filename
    code = if file.match /\.coffee$/ then @read_and_compile file else @read file
    @run code, options

  run: (code, options) ->
    options ?= {}

    @define_with code

    i = 0
    for k, a of @apps
      opts = {}
      if options.port
        opts.port = if options.port[i]? then options.port[i] else a.port + i
      else if i isnt 0
        opts.port = a.port + i

      opts.hostname = options.hostname if options.hostname

      a.start opts
      i++


z = new Zappa()

zappa.version = '0.1.5-pre'
zappa.run = -> z.run.apply z, arguments
zappa.run_file = -> z.run_file.apply z, arguments

