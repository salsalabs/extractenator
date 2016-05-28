require! async
require! cheerio
require! './config'
require! css
fs = require 'fs-extra'
require! path
{compact, each, filter, flatten, map, reject, take-while} = require 'prelude-ls'
require! request
require! url

txdisabled = 'http://txdisabilities.org/'
reddit = "https://reddit.com/r/pics"
stanthonysf = 'https://www.stanthonysf.org/myaccount/'

    
class App
    uri: txdisabled
    dir: \o
    # Always read URLs as buffers buffers.  Convert buffers to string as needed for parsing.

app = new App()

class Task
    @serial-number = 0
    (@referer, @elem, @tag, @attr) ->
        @resolved = null
        @serial-number = @@serial-number++
        @content-type = null
        @status-code = null
        @filename = null

        @get-original!        
        return unless @original?
        return if @original instanceof Object
        u = url.parse @referer
        @resolved = "#{u.protocol}#{@original}" if RegExp '^//' .test @original
        o = url.parse @original
        @resolved = url.resolve @referer, @original unless o.protocol?
        @resolved = @original unless @resolved?

    request: request.defaults do
        jar: true
        encoding: null
        headers:
            'Referer': app.uri
            'User-Agent': config.USER_AGENT

    to-string: ->
        "#{@serial-number} #{@referer} #{@tag} #{@attr} #{@resolved}"

    get-directory: ->
        | /image\//.test @content-type => \image
        | /css/.test @content-type => \css
        | /javascript/.test @content-type => \javascript
        | /font/.test @content-type => \font
        | otherwise ''

    get-filename: (dir) ->
        @filename = (path.join dir, @get-directory!, path.basename @resolved .split '?')[0]
        # console.log "get-filename: #{@to-string!} is filename #{@filename}"
    
    get-html: -> @elem.html!

    read-resolved: (cb) ~>
        return cb null, null unless @resolved?
        (err, resp, body) <~ @request @resolved
        return cb err if err?

        @status-code = resp.statusCode
        @content-type = resp.headers.'content-type'
        return cb null, body if @status-code == 200
        return cb null, null

    save-buffer-to-disk: (body, cb) ~>
        # console.log "save-buffer-to-disk: #{@to-string!}"
        @get-filename app.dir
        target-dir = path.dirname @filename
        err <~ fs.mkdirs target-dir
        cb null if err?

        err <~ fs.writeFile @filename, body, encoding: null
        return cb err if err?
        @store-filename!
        cb null

    save-url-to-disk: (cb) ~>
        # console.log "save-url-to-disk: saving #{@to-string!} to disk"
        err, body <~ @read-resolved
        return cb err if err?
        err <~ @save-buffer-to-disk body
        cb err

    set-html: (body) ->@elem.html body

class CssTask extends Task
    get-original: ->
        @original = @elem.value
        console.log "CssTask: @original is #{@original}"
        pattern = //
            ^(.+url\(['"]*)    # left
            (.+)                # middle -- URL of interest
            (['"]*\))           # right
            //
        @parts = pattern.exec @original
        console.log "#{@to-string!} parts are #{@parts}"
    store-filename: -> @elem.value = "/#{@filename or @resolved}"

class FileTask extends Task
    get-original: -> @original = @elem.attr @attr
    store-filename: -> @elem.attr @attr, "/#{@filename or @resolved}"

class HtmlTask extends Task
    get-original: ->
        @original = @referer
        @resolved = @original
        u = url.parse @original
        u.pathname = path.join u.pathname, '/', "index.html" if path.basename(u.pathname).length == 0
        @resolved = url.format u
        @content-type = 'text/html'

    store-filename: ->

class Extractenator9000
    has-url: (x) -> /url/.test x.value

    not-useful: (t) ->
        return not t.original?
            or not t.resolved?
            or not /^http/.test t.resolved
            or t.resolved.slice(-1) == '/'
            or url.parse t.original .hostname in config.CDN_HOSTS

    load-task-lists: ($) ->
        file-tasks = []
        css-tasks = [] 
        $ 'a' .each -> file-tasks.push new FileTask app.uri, $(this), 'anchor', 'href'
        $ 'script[src*=js]' .each -> file-tasks.push new FileTask app.uri, $(this), 'script', 'src'
        # $ 'style[type*=css]' .each -> queue.push new FileTask app.uri, $(this), 'css-embedded', ''
        $ 'img:not([src^=data])' .each -> file-tasks.push new FileTask app.uri, $(this), 'img', 'src'
        $ 'link[rel=stylesheet]' .each -> css-tasks.push new FileTask app.uri, $(this), 'css', 'href'
        file-tasks: (reject @not-useful, file-tasks), css-tasks: (reject @not-useful, css-tasks)

    modify-declaration: (decl, cb) ->
        console.log "modify-declaration: decl '#{decl.value}' from '#{decl.position.source}'"
        cb null
 
    parse-css-buffer: (t, body, cb) ->
        # console.log "parse-css-buffer: #{t.to-string!}, body has #{body?.length} bytes"
        return cb null unless body?
        obj = css.parse body.toString!, silent: true, source: t.referer
        return cb null unless obj.stylesheet?
        return cb null unless obj.stylesheet.rules?
        decls = obj.stylesheet.rules
            |> map (.declarations)
            |> flatten
            |> compact
            |> filter @has-url
        console.log "parse-css-buffer: #{t.to-string!}, rules have #{decls.length} url declarations"
        err <- async.each decls, @modify-declaration
        return cb err if err?
        cb null, body
        # console.log "parse-css-buffer: #{t.to-string!}, modify-declaration returned err #{err}"
        # return cb err if err?
        # if t.resolved .indexOf \home != -1
        #     # console.log JSON.stringify obj
        #     process.exit 0
        # cb null, css.stringify obj

    parse-embedded-css: (t, cb) ->
        # console.log "parse-embedded-css: #{t.to-string!} parsing #{t.elem.html().length} bytes of embedded CSS"
        (err, body) <- @parse-css-buffer t, t.get-html!
        return cb err if err?
        t.set-html body, cb

    process-css-task: (t, cb) ~>
        # console.log "process-css-task: #{t.to-string!} has resolved #{t.resolved}"
        return cb null unless t.resolved?
        (err, body) <~ t.read-resolved
        # console.log "process-css-task: #{t.to-string!} read-resolved returned err #{err} and #{body.length} bytes"
        return cb err if err?
        (err, body) <~ @parse-css-buffer t, body
        console.log "process-css-task: #{t.to-string!} parse-css-buffer returned err #{err} and #{body.length} bytes"
        return cb err if err?
        t.save-buffer-to-disk body, cb
        
    process-file-task: (t, cb) ~>
        switch t.tag
            | 'anchor' => t.store-filename!; cb null
            | otherwise => t.save-url-to-disk cb
      
    run: (cb) ->
        t = new HtmlTask app.uri, '', '', ''
        err, body <~ t.read-resolved
        return cb err if err?
        $ = cheerio.load body.toString 'utf-8'
        task-lists = @load-task-lists $
        console.log "run: task-lists returned #{task-lists.file-tasks.length} file tasks and #{task-lists.css-tasks.length} CSS tasks"
        err <~ async.each task-lists.css-tasks, @process-css-task
        return cb err if err?
        err <~ async.each task-lists.file-tasks, @process-file-task
        return cb err if err?
        console.log "run: #{t.toString!}"
        t.save-buffer-to-disk $.html!, cb

new Extractenator9000().run (err) ->
    console.log "Extractenator9000: err", err, "on", app.uri if err?
    process.exit 0
