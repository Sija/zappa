jquery = null
coffeekup = null

{scoped, extend} = require './utils'
puts = console.log

class MessageHandler
  constructor: (handler, @app) ->
    @handler = scoped handler
    @locals = null

  init_locals: ->
    @locals = {}
    @locals.app = @app.vars
    @locals.render = @render
    @locals.partial = @partial
    @locals.puts = puts

    for k, v of @app.defs
      @locals[k] = v

    for k, v of @app.helpers
      do (k, v) =>
        @locals[k] = ->
          v @context, @, arguments

    @locals.defs = @app.defs
    @locals.postrenders = @app.postrenders
    @locals.views = @app.views
    @locals.layouts = @app.layouts

  execute: (client, params) ->
    @init_locals() unless @locals?

    @locals.context = {}
    @locals.params = @locals.context
    @locals.client = client
    # TODO: Move this to context.
    @locals.id = client.sessionId
    @locals.send = (title, data) => client.send build_msg(title, data)
    @locals.broadcast = (title, data, except) =>
      except ?= []
      except = [except] if except not instanceof Array
      except.push @locals.id
      @app.ws_server.broadcast build_msg(title, data), except

    for k, v of params
      @locals.context[k] = v

    @handler(@locals.context, @locals)

  render: (template, options) ->
    options ?= {}
    options.layout ?= 'default'

    opts = options.options or {} # Options for the templating engine.
    opts.context ?= @context
    opts.context.zappa = partial: @partial
    opts.locals ?= {}
    opts.locals.partial = (template, context) ->
      text ck_options.context.zappa.partial template, context

    template = @app.views[template] if typeof template is 'string'

    coffeekup = coffeekup || require 'coffeekup'
    result = coffeekup.render template, opts

    if options.layout
      layout = @layouts[options.layout]
      layout_opts = extend {}, opts
      layout_opts.context.content = result
      result = coffeekup.render layout, layout_opts

    if typeof options.apply is 'string'
      options.apply = [options.apply]

    if options.apply?
      jquery = jquery || require 'jquery'
      for name in options.apply
        postrender = @postrenders[name]
        body = jquery 'body'
        body.empty().html result
        postrender opts.context, jquery.extend @defs, { $: jquery }
        result = body.html()

    @send 'render', value: result

    null

  partial: (template, context) =>
    template = @app.views[template]
    coffeekup = coffeekup || require 'coffeekup'
    coffeekup.render template, context: context

exports.MessageHandler = MessageHandler

