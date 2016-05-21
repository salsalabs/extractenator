require! async
require! cheerio
fs = require 'fs-extra'
require! request
require! './config'

class Task
    @serialNumber = 0
    (referer, elem, attr) ->
        @referer = referer
        @elem = elem
        @attr = attr
        @original = @elem.attr @attr
        @serialNumber = @@serialNumber++

class ParseHTML
    (u) ->
        @u = u
        @textRequest = request.defaults do
            jar: true
            encoding: 'utf8'
            headers:
                'Referer': @u
                'User-Agent': config.USER_AGENT
        @rawRequest = @textRequest.defaults encoding:null

    process-task: (t, cb) ->
        console.log "#{t.serialNumber} #{t.elem.get(0).nodeName} #{t.attr} #{t.original}"
        cb null

    run: (cb) ->
        console.log "reading #@u"
        @textRequest @u, (err, resp, body) ~>
            return cb err if err?
            $ = cheerio.load body
            console.log "#{$ 'div' .length} div tags"

            queue = async.queue @process-task, 20
            queue.drain = ->
                console.log 'all done'
                cb null
            $ 'link' .each -> queue.push new Task @u, $(this), 'href', ->
            $ 'img' .each -> queue.push new Task @u, $(this), 'src', ->
            $ 'script' .each -> queue.push new Task @u, $(this), 'src', ->

new ParseHTML 'https://www.reddit.com/r/pics' .run (err) ->
    console.log err if err?
    process.exit 0
