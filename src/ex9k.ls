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
        @httpsCode = null
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

    get-directory: (t) ->
        | /image\//.test t.contentType => \image
        | /css/.test t.contentType => \css
        | /javascript/.test t.contentType => \javascript
        | /font/.test t.contentType => \font
        | otherwise ''

    get-filename: (dir) ->
        @filename = path.join dir, path.basename @resolved .split '?' .first
        console.log '#{@to-string!} is filename #{@filename}'

class CSSTask extends Task
    get-original: -> @original = @elem.value
    save-filename: ->
        @elem.value @filename
        console.log "#{@serialNumber} #{@referer} #{@tag} #{@original} finalized as #{@elem.value}"

class FileTask extends Task
    get-original: -> @original = @elem.attr @attr
    save-filename: ->
        @elem.attr @attr, @filename
        console.log "#{@serialNumber} #{@referer} #{@tag} #{@original} finalized as #{@elem.attr @attr}"

class ParseHTML
    (u, opts) ->
        @u = u
        @opts = opts
        # Always read URLs as buffers buffers.  Convert buffers to string as needed for parsing.
        @rawRequest = request.defaults do
            jar: true
            encoding: null
            headers:
                'Referer': @u
                'User-Agent': config.USER_AGENT
        
    is-cdn: (t) ->
        url.parse t.original .hostname in config.CDN_HOSTS

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
        switch t.tag
            | 'css' => @parse-css-file t, cb
            | 'css-embedded' => @parse-embedded-css t, cb
            | 'anchor' => t.save-filename!; cb null
            | otherwise => @save-to-disk t, cb
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

    save-html-to-disk: (u, $, cb) ->
        # http://stackoverflow.com/questions/982717/how-do-i-get-the-entire-pages-html-with-jquery
        console.log "save-html-to-disk: saving #u to disk"
        cb null

    save-to-disk: (t, cb) ->
        console.log "save-to-disk: #{t.contentType} #{t.to-string!} is on a CDN" if @is-cdn t
        console.log "save-to-disk: saving #{t.contentType} #{t.to-string!} to disk"
        return cb null if @is-cdn t 
        return cb null unless /^http/.test t.resolved
        return cb null unless t.resolved.slice(-1) != '/'
        @rawRequest t.resolved, (err, resp, body) ~>
            return cb err if err?
            t.get-filename @opts.dir
            fs.stat path.basename t.filename, (err, stats) ->
                fs.mkdirs path.basename t.filename, (err) ->
                    return cb err if err?
                    fs.writeFile t.filename, body, encoding: null, (err) ->
                        return cb err
                        console.log "save-to-disk: saving #{t.contentType} #{t.to-string!} to #{t.filename}"
                        cb null

stanthonysf = 'https://www.stanthonysf.org/myaccount/'
fourc = 'https://www.4chan.org/s'
new ParseHTML fourc, dir: 'o' .run (err) ->
    console.log err if err?
    process.exit 0