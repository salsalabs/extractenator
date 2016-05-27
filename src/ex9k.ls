require! async
require! cheerio
require! './config'
require! css
fs = require 'fs-extra'
require! path
{each, filter, flatten, map, reject, take-while} = require 'prelude-ls'
require! request
require! url

class Task
    @serialNumber = 0
    (@referer, @elem, @tag, @attr) ->
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
        @resolved = @original unless @resolved?

    to-string: ->
        "#{@serialNumber} #{@referer} #{@tag} #{@attr} #{@resolved}"

    get-directory:  ->
        | /image\//.test @contentType => \image
        | /css/.test @contentType => \css
        | /javascript/.test @contentType => \javascript
        | /font/.test @contentType => \font
        | otherwise ''

    get-filename: (dir) ->
        @filename = (path.join dir, @get-directory!, path.basename @resolved .split '?')[0]
        # console.log "get-filename: #{@to-string!} is filename #{@filename}"
    
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
    (@u, @opts) ->
        # Always read URLs as buffers buffers.  Convert buffers to string as needed for parsing.
        @request = request.defaults do
            jar: true
            encoding: null
            headers:
                'Referer': @u
                'User-Agent': config.USER_AGENT

    has-url: (x) -> /url/.test x.value

    not-useful: (t) ->
        return not t.original?
            or not t.resolved?
            or not /^http/.test t.resolved
            or t.resolved.slice(-1) == '/'
            or url.parse t.original .hostname in config.CDN_HOSTS

    load-task-lists: ($) ->
        u = @u
        file-tasks = []
        css-tasks = [] 
        $ 'a' .each -> file-tasks.push new FileTask u, $(this), 'anchor', 'href'
        # $ 'link[rel=stylesheet]' .each -> file-tasks.push t = new FileTask u, $(this), 'css', 'href'
        $ 'script[src*=js]' .each -> file-tasks.push new FileTask u, $(this), 'script', 'src'
        # $ 'style[type*=css]' .each -> queue.push new FileTask u, $(this), 'css-embedded', '' ->
        $ 'img:not([src^=data])' .each -> file-tasks.push new FileTask u, $(this), 'img', 'src'
        $ 'link[rel=stylesheet]' .each -> css-tasks.push new FileTask u, $(this), 'css', 'href'
        file-tasks: (reject @not-useful, file-tasks), css-tasks: (reject @not-useful, css-tasks)
 
    parse-css-buffer: (t, body, cb) ->
        console.log "parse-css-buffer: #{t.to-string!}, body has #{body?.length} bytes"
        return cb null unless body?
        obj = css.parse body.toString!, silent: true, source: t.referer
        return cb null unless obj.stylesheet?
        return cb null unless obj.stylesheet.rules?
        decls = take-while (.declarations?.length > 0), obj.stylesheet.rules
            |> map (.declarations)
            |> flatten
            |> filter @has-url
        err <- async.each decls, @process-decl
        return cb err if err?
        cb null, css.stringify obj

    parse-embedded-css: (t, cb) ->
        # console.log "parse-embedded-css: #{t.to-string!} parsing #{t.elem.html().length} bytes of embedded CSS"
        (err, body) <- @parse-css-buffer t, t.get-html!
        return cb err if err?
        t.set-html body, cb

    process-css-task: (t, cb) ~>
        console.log "process-css-task: #{t.to-string!} has resolved #{t.resolved}"
        return cb null unless t.resolved?
        (err, body) <~ @read-resolved t
        return cb err if err?
        (err, body) <~ @parse-css-buffer t, body
        return cb err if err?
        @save-buffer-to-disk t, body, cb

    process-decl: (decl, cb) ->
        console.log "process-decl: decl", decl
        cb null
        
    process-file-task: (t, cb) ~>
        console.log "process-file-task #{t.to-string!}"
        switch t.tag
            | 'anchor' => t.save-filename!; cb null
            | otherwise => @save-url-to-disk t, cb

    read-resolved: (t, cb) ~>
        return cb null, null unless t.resolved?
        # console.log "read-resolved: #{t.to-string!}"
        (err, resp, body) <- @request t.resolved
        return cb err if err?
        t.statusCode = resp.statusCode
        t.contentType = resp.headers['content-type']
        return cb null, body if t.statusCode == 200
        console.log "read-resolved: #{t.statusCode} on read from #{t.resolved}"
        return cb null, null
      
    run: (cb) ->
        # u = @u
        err, resp, body <~ @request @u
        return cb err if err?
        $ = cheerio.load body.toString 'utf-8'
        task-lists = @load-task-lists $
        console.log "run: task-lists returned #{task-lists.file-tasks.length} file tasks and #{task-lists.css-tasks.length} CSS tasks"
        err <~ async.each task-lists.css-tasks, @process-css-task
        return cb err if err?
        err <~ async.each task-lists.file-tasks, @process-file-task
        return cb err if err?
        @save-html-to-disk $, cb

    save-buffer-to-disk: (t, body, cb) ~>
        console.log "save-buffer-to-disk: #{t.to-string!}"
        t.get-filename @opts.dir
        target-dir = path.dirname t.filename
        err <~ fs.mkdirs target-dir
        console.log "save-buffer-to-disk: fs.mkdirs returned err", err
        cb null if err?

        console.log "save-buffer-to-disk: #{t.to-string!} saving #{body.length} bytes to #{t.filename}", err
        err <~ fs.writeFile t.filename, body, encoding: null
        console.log "save-buffer-to-disk: fs.writeFile #{t.filename} returned err", err
        return cb err if err?
        console.log "save-buffer-to-disk: #{t.to-string!} saved #{body.length} bytes to #{t.filename}"
        t.save-filename!
        console.log "save-buffer-to-disk: #{t.to-string!} called t.save-filename! with #{t.filename}"
        cb null

    save-html-to-disk: ($, cb) ~>
        task = new HtmlTask @u, '', '', ''
        console.log "save-html-to-disk, task #{task.to-string!}"
        @save-buffer-to-disk task, $.html!, cb

    save-url-to-disk: (t, cb) ~>
        # console.log "save-url-to-disk: saving #{t.to-string!} to disk"
        err, body <~ @read-resolved t
        return cb err if err?
        err <~ @save-buffer-to-disk t, body
        cb err

txdisabled = 'http://txdisabilities.org/'
reddit = "https://reddit.com/r/pics"
stanthonysf = 'https://www.stanthonysf.org/myaccount/'

u = txdisabled
new Extractenator9000 u, dir: 'o' .run (err) ->
    console.log "Extractenator9000: err", err, "on", u if err?
    process.exit 0