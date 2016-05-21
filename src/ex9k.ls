require! async
require! cheerio
require! css
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
        @contentType = null
        @httpsCode = null
        
        u = url.parse @referer
        return unless @original?
        return if @original instanceof Object
        @resolved = "#{u.protocol}#{@original}" if RegExp '^//' .test @original 
        o = url.parse @original
        @resolved = url.resolve u, @original unless o.protocol?

    to-string: ->
        "#{@serialNumber} #{@referer} #{@tag} #{@attr} #{@resolved}"

class CSSTask extends Task
    save-filename: ->
        @elem.val @resolved

class FileTask extends Task
    save-filename: ->
        @elem.attr @attr, @resolved
        console.log "#{@serialNumber} #{@referer} #{@tag} #{@original} finalized as #{@elem.attr @attr}"
class ParseHTML
    (u) ->
        @u = u
        # Always read URLs as buffers buffers.  Convert buffers to string as needed for parsing.
        @rawRequest = request.defaults do
            jar: true
            encoding: null
            headers:
                'Referer': @u
                'User-Agent': config.USER_AGENT

    # @return [String|Buffer] Returns cleaned contents of the buffer?
    parse-css-buffer: (t, b, cb) ->
        console.log "parse-css-buffer: #{t.to-string!} parsing #{b.length} bytes of CSS"
        # obj = css.parse b.toString(), silent: true
        # tasks = []
        # tasks.push (cb) =>
        #     decls = []
        #     for rule in obj.stylesheet.rules when rule.declarations?
        #         try
        #             d = rule.declarations.filter (x) -> RegExp('url\\(').test x.value
        #             decls = _.union decls, d if d.length > 0
        #         catch err
                     
        #     async.eachSeries decls, @fixDeclaration, cb

        console.log switch t.tag
            | 'css' => "parse-css-buffer: writing file and updating CSS #{t.attr} attribute"
            | 'css-embedded' => 'parse-css-buffer: updating element with CSS'
        cb null

    parse-css-file: (t, cb) ~>
        console.log "parse-css-file: #{t.to-string!} parsing CSS file #{t.resolved}"
        console.log "parse-css-file: reading #{t.resolved}"
        @rawRequest t.resolved, (err, resp, body) ->
            console.log "parse-css-file: read #{t.resolved}, err is #err"
            return cb err if err?
            t.httpsCode = response.statusCode
            t.contentType = response.headers['content-type']
            console.log "parse-css-file: read #{body.length} bytes from #{t.resolved} as #{t.contentType} with code #{t.httpsCode}"
            if t.httpsCode != 200
                console.log 'parse-css-file: #{t.httpsCode} on read from #{t.resolved}'
                return cb null
            @parse-css-buffer t, new Buffer(''), cb
        cb null
    
    parse-embedded-css: (t, cb) ->
        console.log "parse-embedded-css: #{t.to-string!} parsing #{t.elem.html().length} bytes of embedded CSS"
        @parse-css-buffer t, t.elem.html(), cb

    process-task: (t, cb) ~>
        action = switch t.tag
            | 'css' => @parse-css-file t, cb
            | 'css-embedded' => @parse-embedded-css t, cb
            | 'anchor' => t.save-filename!; cb null
            | otherwise => @save-to-disk t, cb
        console.log "process-task: #{t.to-string!} action: #action" 
        cb null

    run: (cb) ->
        console.log "run: reading #{@u}"
        @rawRequest @u, (err, resp, body) ~>
            return cb err if err?
            $ = cheerio.load body.toString 'utf-8'

            queue = async.queue @process-task, 1
            queue.drain = ~>
                console.log 'run: all done'
                @save-html-to-disk @u, $, cb

            u = @u
            $ 'link[href*=css]' .each -> queue.push new FileTask u, $(this), 'css', 'href', ->
            $ 'script[src*=js]' .each -> queue.push new FileTask u, $(this), 'script', 'src', ->
            $ 'style[type*=css]' .each -> queue.push new FileTask u, $(this), 'css-embedded', '' ->
            $ 'img:not([src^=data])' .each -> queue.push new FileTask u, $(this), 'img', 'src', ->
            $ 'a' .each -> queue.push new FileTask u, $(this), 'anchor', 'href', ->

            # Not ready to remove these yet.  All ignored by omission in process-task
            # $ 'link:not([href*=css])' .each -> queue.push new Task u, $(this), 'link', 'href', ->
            # $ 'script:not([src])' .each -> queue.push new Task u, $(this), 'script-embedded', '', ->
            # $ 'img[src^=data]' .each -> queue.push new Task u, $(this), 'data-img', 'src', ->

    save-html-to-disk: (u, $, cb) ->
        # http://stackoverflow.com/questions/982717/how-do-i-get-the-entire-pages-html-with-jquery
        console.log "save-html-to-disk: saving #u to disk"
        cb null

    save-to-disk: (t, cb) ->
        console.log "save-to-disk: saving #{t.contentType} #{t.to-string!} to disk"
        cb null

new ParseHTML 'https://www.4chan.org/s' .run (err) ->
    console.log err if err?
    process.exit 0