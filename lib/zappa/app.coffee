express = require 'express'
jquery = null
io = null
coffeekup = null

{RequestHandler} = require './request_handler'
{MessageHandler} = require './message_handler'
{scoped, parse_msg, extend} = require './utils'
puts = console.log

class App
  constructor: (@name, options = {}, vars = {}) ->
    @name ?= 'default'
    @options =
      port: 5678
      static_dir: "#{process.cwd()}/public"
      session:
        secret: 'change me!'

    if options instanceof Function
      options = { configure: options }
    if configure = options.configure
      delete options.configure

    @options = extend @options, options, true

    @http_server = express.createServer()
    @http_server.use express.cookieParser()
    @http_server.use express.bodyParser()
    @http_server.use express.session @options.session if @options.session
    @http_server.use express.static @options.static_dir if @options.static_dir

    if coffeekup?
      @http_server.register '.coffee', coffeekup
      @http_server.set 'view engine', 'coffee'

    @http_server.configure =>
      configure @http_server, @options if configure?

    # App-level vars, exposed to handlers as [app].
    @vars = vars

    @defs = {}
    @helpers = {}
    @postrenders = {}
    @socket_handlers = {}
    @msg_handlers = {}

    @views = {}
    @layouts = {}
    @layouts.default = ->
      doctype 5
      html ->
        head ->
          title @title if @title
          if @scripts
            for s in @scripts
              script src: s + '.js'
          script(src: @script + '.js') if @script
          if @stylesheets
            for s in @stylesheets
              link rel: 'stylesheet', href: s + '.css'
          link(rel: 'stylesheet', href: @stylesheet + '.css') if @stylesheet
          style @style if @style
        body @content

  start: (options) ->
    options ?= {}
    @options.port = options.port if options.port
    @options.hostname = options.hostname if options.hostname

    if io?
      @ws_server = io.listen @http_server, {log: ->}
      @ws_server.on 'connection', (client) =>
        @socket_handlers.connection?.execute client
        client.on 'disconnect', => @socket_handlers.disconnection?.execute client
        client.on 'message', (raw_msg) =>
          msg = parse_msg raw_msg
          @msg_handlers[msg.title]?.execute client, msg.params

    if @options.hostname?
      @http_server.listen @options.port, @options.hostname
    else
      @http_server.listen @options.port

    puts "App \"#{@name}\" listening on #{@options.hostname or '*'}:#{@options.port}..."
    @http_server

  get:  -> @route 'get',  arguments
  post: -> @route 'post', arguments
  put:  -> @route 'put',  arguments
  del:  -> @route 'del',  arguments
  route: (verb, args) ->
    if typeof args[0] isnt 'object'
      @register_route verb, args[0], args[1]
    else
      for k, v of args[0]
        @register_route verb, k, v

  register_route: (verb, path, response) ->
    if typeof response isnt 'function'
      @http_server[verb] path, (req, res) -> res.send String(response)
    else
      handler = new RequestHandler(response, @defs, @helpers, @postrenders, @views, @layouts, @vars)
      @http_server[verb] path, (req, res, next) ->
        handler.execute req, res, next

  using: ->
    pairs = {}
    for a in arguments
      pairs[a] = require(a)
    @def pairs

  def: (pairs) ->
    for k, v of pairs
      @defs[k] = v

  helper: (pairs) ->
    for k, v of pairs
      @helpers[k] = scoped v

  postrender: (pairs) ->
    jquery = jquery || require 'jquery'
    for k, v of pairs
      @postrenders[k] = scoped v

  at: (pairs) ->
    io = io || require 'socket.io'
    for k, v of pairs
      @socket_handlers[k] = new MessageHandler v, @

  msg: (pairs) ->
    io = io || require 'socket.io'
    for k, v of pairs
      @msg_handlers[k] = new MessageHandler v, @

  layout: (arg) ->
    pairs = if typeof arg is 'object' then arg else { default: arg }
    coffeekup = coffeekup || require 'coffeekup'
    for k, v of pairs
      @layouts[k] = v

  view: (arg) ->
    pairs = if typeof arg is 'object' then arg else { default: arg }
    coffeekup = coffeekup || require 'coffeekup'
    for k, v of pairs
      @views[k] = v

  client: (arg) ->
    pairs = if typeof arg is 'object' then arg else { default: arg }
    for k, v of pairs
      do (k, v) =>
        code = ";(#{v})();"
        @http_server.get "/#{k}.js", (req, res) ->
          res.contentType "#{k}.js"
          res.send code

  style: (arg) ->
    pairs = if typeof arg is 'object' then arg else { default: arg }
    for k, v of pairs
      do (k, v) =>
        @http_server.get "/#{k}.css", (req, res) ->
          res.contentType "#{k}.css"
          res.send v

exports.App = App

