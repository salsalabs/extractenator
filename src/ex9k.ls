require! async
require! cheerio
require! './config'
require! css
fs = require 'fs-extra'
require! path
{each, filter, flatten, map, take-while} = require 'prelude-ls'
require! request
require! url

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
        # console.log "get-filename: #{@to-string!}"
        @filename = (path.join dir, @get-directory!, path.basename @resolved .split '?')[0]
        console.log "get-filename: #{@to-string!} is filename #{@filename}"
    
    get-html: -> @elem.html!

    set-html: (body) ->@elem.html body

class FileTask extends Task
    get-original: -> @original = @elem.attr @attr
    save-filename: -> @elem.attr @attr, "/#{@filename or @resolved}"

class HtmlTask extends Task
    get-original: ->
        @original = @referer
        @resolved = @original
        @resolved = path.join @original, '/', "index.html" unless path.extname @original?
        @contentType = 'text/html'
    save-filename: ->

class Extractenator9000
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

    fix-url: (x) -> x.value = x.value.replace 'url', 'URL'

    has-url: (x) -> /url/.test x.value

    is-cdn: (t) ->
        url.parse t.original .hostname in config.CDN_HOSTS

    parse-css-buffer: (t, body, cb) ->
        obj = css.parse body.toString!, silent: true, source: t.referer
        return cb null unless obj.stylesheet?
        return cb null unless obj.stylesheet.rules?
        take-while (.declarations?.length > 0), obj.stylesheet.rules
            |> map (.declarations)
            |> flatten
            |> filter @has-url
            |> each @fix-url
        cb null, css.stringify obj

    parse-css-file: (t, cb) ~>
        # console.log "parse-css-file: #{t.to-string!} parsing file"
        tasks = 
            * (cb) ~> @read-resolved t, cb
            * (body, cb) ~> @parse-css-buffer t, body, cb
            * (body, cb) ~> @save-buffer-to-disk t, body, cb
        async.waterfall tasks, cb

    parse-embedded-css: (t, cb) ->
        # console.log "parse-embedded-css: #{t.to-string!} parsing #{t.elem.html().length} bytes of embedded CSS"
        tasks = 
            * (cb) ~>@parse-css-buffer t, t.get-html!, cb
            * (body, cb) ~> t.set-html body, cb
        async.waterfall tasks, cb

    process-css: (t, cb) ~>
        console.log "process-css #{t.to-string!}"
        cb null

    process-file: (t, cb) ~>
        console.log "process-file #{t.to-string!}"
        switch t.tag
            | 'anchor' => t.save-filename!; cb null
            | otherwise => @save-url-to-disk t, cb

    read-resolved: (t, cb) ->
        @request t.resolved, (err, resp, body) ~>
            return cb err if err?
            t.statusCode = resp.statusCode
            t.contentType = resp.headers['content-type']
            # Ignore HTTP errors
            if t.statusCode != 200
                console.log 'read-resolved: #{t.statusCode} on read from #{t.resolved}'
                return cb null, null
            cb null, body

    load-task-lists: ($, cb) ->
        u = @u
        files = []
        css-files = [] 
        $ 'link[href*=css]' .each ->
            t = new FileTask u, $(this), 'css', 'href'
            files.push t
            css-files.push t
        $ 'script[src*=js]' .each -> files.push new FileTask u, $(this), 'script', 'src'
        # $ 'style[type*=css]' .each -> queue.push new FileTask u, $(this), 'css-embedded', '' ->
        $ 'img:not([src^=data])' .each -> files.push new FileTask u, $(this), 'img', 'src'
        $ 'a' .each -> files.push new FileTask u, $(this), 'anchor', 'href'
        cb null, $, files, css-files
       
    run: (cb) ->
        u = @u
        tasks =
            * (cb) ~>@request u, cb
            * (resp, body, cb) ~> cb null, cheerio.load body.toString 'utf-8'
            * ($, cb) ~> @load-task-lists $, cb
            * ($, files, css-files, cb) ~> 
                file-tasks =
                    * (cb) ~> async.each files, @process-file, cb
                    * (cb) ~> async.each css-files, @process-css, cb
                async.waterfall file-tasks, (err) -> cb err, $
            * ($, cb) ~> @save-html-to-disk $, cb
        async.waterfall tasks, cb

    save-buffer-to-disk: (t, body, cb) ->
        # console.log "save-buffer-to-disk: #{t.to-string!}"
        t.get-filename @opts.dir
        target-dir = path.dirname t.filename
        tasks = 
            * (cb) ~> fs.stat target-dir, (err, stats) -> cb null, stats
            * (stats, cb) ~> return cb null if stats?; fs.mkdirs target-dir, cb
            * (cb) ~> fs.writeFile t.filename, body, encoding: null, cb
            * (cb) ~> t.save-filename!; cb null
        async.waterfall tasks, (err) ->
            console.log "save-buffer-to-disk: err", err if err?
            # console.log "save-buffer-to-disk: #{t.to-string!} saved as #{t.content-type} file #{t.filename}"
            cb null

    save-html-to-disk: ($, cb) ->
        task = new HtmlTask @u, '', '', ''
        console.log "save-html-to-disk, task #{task.to-string!}"
        @save-buffer-to-disk task, $.html!, cb

    save-url-to-disk: (t, cb) ->
        console.log "save-url-to-disk: #{t.to-string!} is on a CDN" if @is-cdn t
        return cb null if @is-cdn t 
        return cb null unless /^http/.test t.resolved
        return cb null unless t.resolved.slice(-1) != '/'
        console.log "save-url-to-disk: saving #{t.to-string!} to disk"
        tasks = 
            * (cb) ~> @read-resolved t, cb
            * (body, cb) ~> @save-buffer-to-disk t, body, cb
        async.waterfall tasks, cb

txdisabled = 'http://txdisabilities.org/'
reddit = "https://reddit.com/r/pics"
stanthonysf = 'https://www.stanthonysf.org/myaccount/'
new Extractenator9000 txdisabled, dir: 'o' .run (err) ->
    console.log err if err?
    process.exit 0