require! async
require! cheerio
fs = require 'fs-extra'
require! request
require! url
require! './config'

class Task
    @serialNumber = 0
    (referer, elem, tag, attr) ->
        @referer = referer
        @elem = elem
        @tag = tag
        @attr = attr
        @original = @elem.attr @attr
        @resolved = null
        @serialNumber = @@serialNumber++
        
        u = url.parse @referer
        @resolved = "#{u.protocol}#{@original}" if RegExp '^//' .test @original 
        return unless @resolved?
        o = url.parse @original
        @resolved = url.resolve u, @original unless o.protocol?

    to-string: ->
        "#{@serialNumber} #{@referer} #{@tag} #{@attr} #{@resolved}"
        
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
        action = switch t.tag
            | 'css' => 'parse-css file'
            | 'link' => 'ignored'
            | 'script-embedded' => 'embedded script'
            | 'css-embedded' => "parse embedded css"
            | 'data-img' => 'data-img ignored'
            | otherwise => 'save to disk'
        console.log "#{t.to-string!} action: #action" 
        cb null

    run: (cb) ->
        console.log "reading #{@u}"
        @textRequest @u, (err, resp, body) ~>
            console.log "read #{@u}"
            return cb err if err?
            $ = cheerio.load body

            queue = async.queue @process-task, 20
            queue.drain = ->
                console.log 'all done'
                cb null
            u = @u
            $ 'link[href*=css]' .each -> queue.push new Task u, $(this), 'css', 'href', ->
            $ 'link:not([href*=css])' .each -> queue.push new Task u, $(this), 'link', 'href', ->
            $ 'script[src*=js]' .each -> queue.push new Task u, $(this), 'script', 'src', ->
            $ 'script:not([src])' .each -> queue.push new Task u, $(this), 'script-embedded', '', ->
            $ 'style[type*=css]' .each -> queue.push new Task u, $(this), 'css-embedded', '' ->
            $ 'img:not([src^=data])' .each -> queue.push new Task u, $(this), 'img', 'src', ->
            $ 'img[src^=data]' .each -> queue.push new Task u, $(this), 'data-img', 'src', ->

new ParseHTML 'https://www.4chan.org/s' .run (err) ->
    console.log err if err?
    process.exit 0
