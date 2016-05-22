require! async
require! cheerio
require! css
fs = require 'fs-extra'
require! path
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
        @resolved = null
        @serialNumber = @@serialNumber++
        @contentType = null
        @statusCode = null
        @filename = null

        @get-original!        
        return unless @original?
        return if @original instanceof Object
        u = url.parse @referer
        @resolved = "#{u.protocol}#{@original}" if RegExp '^//' .test @original 
        o = url.parse @original
        @resolved = url.resolve u, @original unless o.protocol?

    to-string: ->
        "#{@serialNumber} #{@referer} #{@tag} #{@attr} #{@resolved}"

    get-directory:  ->
        | /image\//.test @contentType => \image
        | /css/.test @contentType => \css
        | /javascript/.test @contentType => \javascript
        | /font/.test @contentType => \font
        | otherwise ''

    get-filename: (dir) ->
        console.log "get-filename: #{@to-string!}"
        # @filename = head path.join dir, path.basename @resolved .split '?'
        @filename = (path.join dir, @get-directory!, path.basename @resolved .split '?')[0]
        console.log "get-filename: #{@to-string!} is filename #{@filename}"

class CSSTask extends Task
    get-original: -> @original = @elem.value
    save-filename: -> @elem.value (@filename or @resolved)

class FileTask extends Task
    get-original: -> @original = @elem.attr @attr
    save-filename: -> @elem.attr @attr, (@filename or @resolved)

class HtmlTask extends Task
    get-original: -> @original = @referer
    save-filename: ->

class ParseHTML
    (u, opts) ->
        @u = u
        @opts = opts
        # Always read URLs as buffers buffers.  Convert buffers to string as needed for parsing.
        @request = request.defaults do
            jar: true
            encoding: null
            headers:
                'Referer': @u
                'User-Agent': config.USER_AGENT

    fix-css-eclaration: (decl, cb) ~>
        # console.log "CSSParser.fixDeclaration: decl is", decl
        u = /url\(['"]*(.+?)['"]*\)/.exec(decl.value)[1]
        task = new CssTask

    is-cdn: (t) ->
        url.parse t.original .hostname in config.CDN_HOSTS

    # @return [String|Buffer] Returns cleaned contents of the buffer?
    parse-css-buffer: (t, b, cb) ->
        # console.log "parse-css-buffer: #{t.to-string!} parsing #{b.length} bytes of CSS"
        # obj = css.parse b.toString(), silent: true
        # decls = []
        # for rule in obj.stylesheet.rules when rule.declarations?
        #     try
        #         decls = decls ++ rule.declarations.filter (x) -> RegExp('url\\(').test x.value
        #     catch err
        # async.eachSeries decls, @fix-css-declaration, cb

        # console.log switch t.tag
        #     | 'css' => "parse-css-buffer: writing file and updating CSS #{t.attr} attribute"
        #     | 'css-embedded' => 'parse-css-buffer: updating element with CSS'
        cb null

    parse-css-file: (t, cb) ~>
        console.log "parse-css-file: #{t.to-string!} parsing file"
        tasks = 
            * (cb) ~> @read-resolved t, cb
            * (body, cb) ~> @parse-css-buffer t, body, cb
        async.waterfall tasks, cb

    parse-embedded-css: (t, cb) ->
        console.log "parse-embedded-css: #{t.to-string!} parsing #{t.elem.html().length} bytes of embedded CSS"
        @parse-css-buffer t, t.elem.html(), cb

    process-task: (t, cb) ~>
        switch t.tag
            | 'css' => @parse-css-file t, cb
            | 'css-embedded' => @parse-embedded-css t, cb
            | 'anchor' => t.save-filename!; cb null
            | otherwise => @save-to-disk t, cb

    read-resolved: (t, cb) ->
        console.log "read-resolved: reading #{t.resolved}"
        @request t.resolved, (err, resp, body) ~>
            console.log "read-resolved: read #{t.resolved}, err is #err"
            return cb err if err?
            t.statusCode = resp.statusCode
            t.contentType = resp.headers['content-type']
            console.log "read-resolved: read #{body.length} bytes from #{t.resolved} as #{t.contentType} with code #{t.statusCode}"
            # Ignore HTTP errors
            if t.statusCode != 200
                console.log 'read-resolved: #{t.statusCode} on read from #{t.resolved}'
                return cb null
            cb null, body

    run: (cb) ->
        console.log "run: reading #{@u}"
        @request @u, (err, resp, body) ~>
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

    save-html-to-disk: (u, $, cb) ->
        task = new HtmlTask u, '', '', ''
        body = $.html!
        @save-buffer-to-disk task, body, cb

    save-buffer-to-disk: (t, body, cb) ->
        t.get-filename @opts.dir
        target-dir = path.dirname t.filename
        fs.stat target-dir, (err, stats) ->
            console.log "save-to-disk: fs.stat(#{path.dirname t.filename}) returned (#err, stats)"
            fs.mkdirs target-dir, (err) ->
                return cb err if err?
                fs.writeFile t.filename, body, encoding: null, (err) ->
                    return cb err
                    console.log "save-to-disk: saving #{t.contentType} #{t.to-string!} to #{t.filename}"
                    cb null
        
    save-to-disk: (t, cb) ->
        console.log "save-to-disk: #{t.to-string!} is on a CDN" if @is-cdn t
        console.log "save-to-disk: saving #{t.to-string!} to disk"
        return cb null if @is-cdn t 
        return cb null unless /^http/.test t.resolved
        return cb null unless t.resolved.slice(-1) != '/'
        @read-resolved t, (err, body) ~>
            return cb err if err?
            @save-buffer-to-disk t, body, cb

stanthonysf = 'https://www.stanthonysf.org/myaccount/'
fourc = 'https://www.4chan.org/s'
new ParseHTML fourc, dir: 'o' .run (err) ->
    console.log err if err?
    process.exit 0