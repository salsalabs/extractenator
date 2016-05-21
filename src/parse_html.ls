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
        # Always read buffers.  Convert buffers to string as needed for parsing.
        @rawRequest = request.defaults do
            jar: true
            encoding: null
            headers:
                'Referer': @u
                'User-Agent': config.USER_AGENT

    parse-css-buffer: (t, b, cb) ->
        console.log "parse-css-buffer: #{t.to-string!} parsing #{b.length} bytes of CSS"
        console.log switch t.tag
            | 'css' => "parse-css-buffer: writing file and updating CSS #{t.attr} attribute"
            | 'css-embedded' => 'parse-css-buffer: updating element with CSS'
        cb null

    parse-css-file: (t, cb) ->
        console.log "parse-css: #{t.to-string!} parsing CSS file #{t.resolved}"
        @parse-css-buffer t, new Buffer(''), cb
        cb null
    
    parse-embedded-css: (t, cb) ->
        content = t.elem.html()
        console.log "parse-embedded-css: #{t.to-string!} parsing #{content.length} bytes of embedded CSS"
        @parse-css-buffer t, content, cb

    process-task: (t, cb) ~>
        action = switch t.tag
            | 'css' => @parse-css-file t, cb
            | 'css-embedded' => @parse-embedded-css t, cb
            | otherwise => @save-to-disk t, cb
        console.log "process-task: #{t.to-string!} action: #action" 
        cb null

    run: (cb) ->
        console.log "run: reading #{@u}"
        @rawRequest @u, (err, resp, body) ~>
            return cb err if err?
            $ = cheerio.load body.toString 'utf-8'

            queue = async.queue @process-task, 20
            queue.drain = ->
                console.log 'run: all done'
                cb null
            u = @u
            $ 'link[href*=css]' .each -> queue.push new Task u, $(this), 'css', 'href', ->
            $ 'script[src*=js]' .each -> queue.push new Task u, $(this), 'script', 'src', ->
            $ 'style[type*=css]' .each -> queue.push new Task u, $(this), 'css-embedded', '' ->
            $ 'img:not([src^=data])' .each -> queue.push new Task u, $(this), 'img', 'src', ->

            # Not ready to remove these yet.  All ignored by omission in process-task
            # $ 'link:not([href*=css])' .each -> queue.push new Task u, $(this), 'link', 'href', ->
            # $ 'script:not([src])' .each -> queue.push new Task u, $(this), 'script-embedded', '', ->
            # $ 'img[src^=data]' .each -> queue.push new Task u, $(this), 'data-img', 'src', ->

    save-to-disk: (t, cb) ->
        console.log "save-to-disk: #{t.to-string!} saved to disk"
        cb null

new ParseHTML 'https://www.4chan.org/s' .run (err) ->
    console.log err if err?
    process.exit 0
