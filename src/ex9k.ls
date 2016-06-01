require! async
require! cheerio
require! './config'
require! css
fs = require 'fs-extra'
require! path
{compact, each, filter, flatten, head, map, reject} = require 'prelude-ls'
require! request
require! url
{Org} = require './org'

org = new Org()
console.log "org: ", org

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
        o = url.parse @original
        @resolved = url.resolve @referer, @original unless o.protocol?
        @resolved = @original unless @resolved?

    request: request.defaults do
        jar: true
        encoding: null
        headers:
            'Referer': org.uri
            'User-Agent': config.USER_AGENT

    get-basename: ->
        basename = (path.basename @resolved .split '?')[0]
        return 'index.html' unless path.extname basename .length > 0
        basename

    get-directory: ->
        | /image\//.test @content-type => \image
        | /css/.test @content-type => \css
        | /javascript/.test @content-type => \javascript
        | /font/.test @content-type => \font
        | otherwise ''

    get-filename: (dir) ->
        @filename = path.join dir, @get-directory!, @get-basename!

    get-html: -> @elem.html!

    read-resolved: (cb) ~>
        # console.log "read-resolved: #{@to-string!} null resolved #{not resolved?}"
        return cb null, null unless @resolved?
        (err, resp, body) <~ @request @resolved
        return cb err if err?

        @status-code = resp.statusCode
        @content-type = resp.headers.'content-type'
        return cb null, body if @status-code == 200
        cb null, null

    save-buffer-to-disk: (body, cb) ~>
        # console.log "save-buffer-to-disk: #{@to-string!}"
        @get-filename org.dir
        target-dir = path.dirname @filename
        err <~ fs.mkdirs target-dir
        console.log "save-buffer-to-dir mkdirs returned #err" if err?
        return cb null if err?

        console.log "save-buffer-to-disk: #{@filename}"
        err <~ fs.writeFile @filename, body, encoding: null
        return cb err if err?
        @store-filename!
        cb null

    save-url-to-disk: (cb) ~>
        # console.log "save-url-to-disk: saving #(@content-type} #{@to-string!} to disk"
        err, body <~ @read-resolved
        return cb err if err?
        err <~ @save-buffer-to-disk body
        cb err

    set-html: (body) ->@elem.html body

    to-string: ->
        "#{@serial-number} #{@referer} #{@tag} #{@attr} #{@resolved}"

class DeclTask extends Task
    get-original: ->
        pattern = /^(.*url\(['"]*)(.+?)(['"]*\).*)/
        @parts = pattern.exec @elem.value
        @original = @parts[2]

    store-filename: ->
        @parts[2] = "#{org.root-dir}#{@filename or @resolved}"
        @elem.value = @parts .slice 1 .join ''

class FileTask extends Task
    get-original: -> @original = @elem.attr @attr
    store-filename: -> @elem.attr @attr, "#{org.root-dir}#{@filename or @resolved}"

class HtmlTask extends Task
    get-original: ->
        @original = @referer
        @resolved = @original
        @content-type = 'text/html'

    store-filename: ->

class ImportTask extends Task
    get-original: ->
        pattern = /^(.*url\(['"]*)(.+?)(['"]*\).*)/
        @parts = pattern.exec @elem.import
        @original = @parts[2]

    store-filename: ->
        @parts[2] = "#{org.root-dir}#{@filename or @resolved}"
        @elem.import = @parts .slice 1 .join ''

class Extractenator9000
    not-useful: (t) ->
        switch t.tag
            | 'css-embedded' => false
            | otherwise
                not t.original?
                or not t.resolved?
                or not /^http/.test t.resolved
                or t.resolved.slice(-1) == '/'
                or url.parse t.original .hostname in config.CDN_HOSTS

    load-task-list: ($) ->
        task-list = []
        $ 'a' .each -> task-list.push new FileTask org.uri, $(this), 'anchor', 'href'
        $ 'script[src*=js]' .each -> task-list.push new FileTask org.uri, $(this), 'script', 'src'
        $ 'img:not([src^=data])' .each -> task-list.push new FileTask org.uri, $(this), 'img', 'src'
        $ 'link[rel=stylesheet]' .each -> task-list.push new FileTask org.uri, $(this), 'css', 'href'
        $ 'style[type*=css]' .each -> task-list.push new FileTask org.uri, $(this), 'style', ''
        reject @not-useful, task-list
        
    process-css-buffer: (t, body, cb) ->
        # console.log "process-css-buffer: #{t.to-string!}, body has #{body?.length} bytes
        return cb null unless body?
        obj = css.parse body.toString!, silent: true, source: t.referer
        return cb null unless obj.stylesheet?
        return cb null unless obj.stylesheet.rules?
        err <~ @process-decl-list t, obj
        return cb err if err?
        err <~ @process-import-list t, obj
        return cb err if err?
        cb null, css.stringify obj

    process-css-decl: (t, cb) ->t.save-url-to-disk cb

    process-css-file-task: (t, cb) ~>
        # console.log "process-css-task: #{t.to-string!} has resolved #{t.resolved}"
        (err, body) <~ t.read-resolved
        return cb err if err?
        (err, body) <~ @process-css-buffer t, body
        return cb err if err?
        t.save-buffer-to-disk body, cb

    process-decl-list: (t, obj, cb) ->
        decls = obj.stylesheet.rules
            |> map (.declarations)
            |> flatten
            |> compact
            |> filter (declaration) -> /url/.test declaration.value
        tasks = decls.map (it) -> new DeclTask t.resolved, it, '', ''
        err <~ async.each tasks, @process-css-decl
        return cb err

    process-import-list: (t, obj, cb) ->
        rules = obj.stylesheet.rules
            |> filter (.import)
            |> compact
            |> filter (rule) -> rule.import.indexOf('url(') != -1
        tasks = rules.map (it) -> new ImportTask t.resolved, it, '', ''
        err <~ async.each tasks, @process-css-decl
        return cb err

    process-style-task: (t, cb) ->
        # console.log "parse-embedded-css: #{t.to-string!} parsing #{t.elem.html().length} bytes of embedded CSS"
        (err, body) <- @process-css-buffer t, t.get-html!
        return cb err if err?
        t.set-html body, cb

    process-task-list: (t, cb) ~>
        switch t.tag
            | 'anchor' => t.store-filename!; cb null
            | 'style' => @process-style-task t, cb
            | 'css' => @process-css-file-task t, cb
            | otherwise => t.save-url-to-disk cb
      
    run: (cb) ->
        t = new HtmlTask org.uri, '', '', ''
        err, body <~ t.read-resolved
        return cb err if err?
        $ = cheerio.load body.toString 'utf-8'
        task-list = @load-task-list $
        err <~ async.each task-list, @process-task-list
        return cb err if err?
        t.save-buffer-to-disk $.html!, cb

new Extractenator9000().run (err) ->
    # console.log "Extractenator9000: err", err, "on", org.uri if err?
    process.exit 0
