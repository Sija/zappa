jquery = null
coffeekup = null

{scoped} = require './utils'
puts = console.log

class RequestHandler
  constructor: (handler, @defs, @helpers, @postrenders, @views, @layouts, @vars) ->
    @handler = scoped handler
    @locals = null

  init_locals: ->
    @locals = {}
    @locals.app = @vars
    @locals.render = @render
    @locals.partial = @partial
    @locals.redirect = @redirect
    @locals.send = @send
    @locals.puts = puts

    for k, v of @defs
      @locals[k] = v

    for k, v of @helpers
      do (k, v) =>
        @locals[k] = ->
          v @context, @, arguments

    @locals.defs = @defs
    @locals.postrenders = @postrenders
    @locals.views = @views
    @locals.layouts = @layouts

  execute: (request, response, next) ->
    @init_locals() unless @locals?

    @locals.context = {}
    @locals.params = @locals.context

    @locals.request = request
    @locals.response = response
    @locals.next = next

    @locals.session = request.session
    @locals.cookies = request.cookies

    for k, v of request.query
      @locals.context[k] = v
    for k, v of request.params
      @locals.context[k] = v
    for k, v of request.body
      @locals.context[k] = v

    result = @handler(@locals.context, @locals)

    if typeof result is 'string'
      response.send result
    else
      result

  redirect: -> @response.redirect.apply @response, arguments
  send: -> @response.send.apply @response, arguments

  render: (template, options) ->
    options ?= {}
    options.layout ?= 'default'

    opts = options.options or {} # Options for the templating engine.
    opts.context ?= @context
    opts.context.zappa = partial: @partial
    opts.locals ?= {}
    opts.locals.partial = (template, context) ->
      text ck_options.context.zappa.partial template, context

    template = @views[template] if typeof template is 'string'

    coffeekup = require 'coffeekup'
    result = coffeekup.render template, opts

    if typeof options.apply is 'string'
      postrender = @postrenders[options.apply]
      jquery = require 'jquery'
      body = jquery 'body'
      body.empty().html result
      postrender opts.context, jquery.extend @defs, { $: jquery }
      result = body.html()

    if options.layout
      layout = @layouts[options.layout]
      opts.context.content = result
      result = coffeekup.render layout, opts

    @response.send result

    null

  partial: (template, context) =>
    template = @views[template]
    coffeekup = require 'coffeekup'
    coffeekup.render template, context: context

exports.RequestHandler = RequestHandler

