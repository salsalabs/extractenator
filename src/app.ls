require! {
    cheerio
    async
    './config'
    css
    'fs-extra': fs
    path
    'prelude-ls': { compact, each, filter, flatten, head, map, reject, replace } 
    request
    url
    './org': { Org }
}
org = new Org()

class Task
    @serial-number = 0
    @url-cache = {}

    (@referer, @elem, @tag, @attr) ->
        @resolved = null
        @content-type = null
        @status-code = null
        @filename = null

        @get-original!        
        @get-resolved!

    get-original: -> @original = null
 
    request: request.defaults do
        # https://stackoverflow.com/questions/8880741/node-js-easy-http-requests-with-gzip-deflate-compression
        gzip: true
        jar: true
        encoding: null
        headers:
            'Referer': org.uri
            'User-Agent': config.USER_AGENT

    clean-basename: (v) -> v .split /[\?\&\;\#]/ .0

    get-basename: ->
        try
            basename = (path.basename @resolved .split '?')[0]            
            return @clean-basename basename if path.extname basename .length > 0
            extension = (@content-type .split '/' .1)
        catch thrown
            console.log "get-basename: @resolved is a #{typeof @resolved}"
            console.log "path.basename threw #{thrown}"
            basename = "unknown"
            extension="unknown"        
        return @clean-basename "#{basename || ++@@serial-number}.#{extension}"

    get-directory: ->
        | /image\//.test @content-type => \image
        | /css/.test @content-type => \css
        | /javascript/.test @content-type => \javascript
        | /font/.test @content-type => \font
        | otherwise ''

    get-html: -> @elem.html!

    get-resolved: ->
        @resolved = @original
        return unless @original?
        return if @original instanceof Object
        protocol = url.parse @original .protocol
        @referer = switch @referer | null => org.uri | otherwise => @referer
        try
            @resolved = url.resolve @referer, @original unless protocol?
        catch thrown
            console.log "URL.resolve threw #{thrown}"
            console.log "referer is #{@referer}"
            console.log "original is #{@original}"
            console.log "\n"
            esolved = null
        @resolved = @original unless @resolved?

    read-resolved: (cb) ~>
        console.log "read-resolved: #{@to-string!} null resolved #{not @resolved?}"
        return cb null, null unless @resolved?
        return cb null, null if @resolved.indexOf('data:') != -1
        (err, resp, body) <~ @request @resolved
        if err?
            console.log "read-resolved:#{@resolved}"
            console.log "read-resolved: caught #{err}"
            return cb null, null

        @status-code = resp.statusCode
        @content-type = resp.headers.'content-type'
        console.log "Task:read-resolved: #{@status-code} on #{@resolved}" if @status-code != 200
        return cb null, body if @status-code == 200
        cb null, null

    save-buffer-to-disk: (body, cb) ~>
        # console.log "save-buffer-to-disk: #{@to-string!}"
        @filename = path.join org.dir, @get-directory!, @get-basename!
        local-filename = switch @filename.slice 0 1
            | '/' => @filename.slice 1
            | otherwise => @filename
        target-dir = path.dirname local-filename
        err <~ fs.mkdirs target-dir
        console.log "save-buffer-to-dir mkdirs returned #err" if err?
        return cb null if err?

        err <~ fs.writeFile local-filename, body, encoding: null
        return cb err if err?
        @store-filename!
        cb null

    save-url-to-disk: (cb) ~>
        # console.log "save-url-to-disk: saving #{@content-type} #{@resolved} to disk"
        return cb null unless @resolved?
        if @@url-cache.hasOwnProperty @resolved
            # console.log "save-url-to-disk: #{@resolved} found in cache"
            return cb null
        # console.log "save-url-to-disk: #{@resolved} not in cache"
        @@url-cache[@resolved] = true

        err, body <~ @read-resolved
        console.log "save-url-to-disk: caught error #{err} while reading #{@resolved}" if err?
        return cb err if err?
        # console.log "save-url-to-disk: caught error 'empty body' with status #{@status-code} on #{@resolved}" unless body?
        return cb null unless body?
        err <~ @save-buffer-to-disk body
        console.log "save-url-to-disk: caught error #{err} while saving #{@resolved}" if err?
        cb null

    set-html: (body) ->@elem.html body

    to-string: ->
        "#{@tag} #{@attr} #{@resolved} #{@filename}"

class DeclTask extends Task
    get-original: ->
        pattern = //
            (.*url\(['"]*)
            (.+?)
            (['"]*\).*)
            //
        @matches = pattern.exec @elem.value
        return @original = null unless @matches?
        @original = @matches[2] if @matches.length > 2

    store-filename: ->
        return unless @matches? and @matches.length > 2
        @matches[2] = "#{@filename or @resolved}"
        @elem.value = @matches .slice 1 .join ''
        console.log @elem.property, @elem.value

class FileTask extends Task
    get-original: -> @original = @elem.attr @attr; console.log "FileTask: #{@tag} #{@attr} #{@original}"; @original
    store-filename: -> @elem.attr @attr, "#{@filename or @resolved}"

class HtmlTask extends Task
    get-original: ->
        @original = @referer
        @resolved = @original
        @content-type = 'text/html'

    store-filename: ->

class ImportTask extends Task
    get-original: ->
        pattern = /^(.*url\(['"]*)(.+?)(['"]*\).*)/
        @matches = pattern.exec @elem.import
        @original = @matches[2]

    store-filename: ->
        @matches[2] = "#{@filename or @resolved}"
        @elem.import = @matches .slice 1 .join ''

class Extractenator9000
    not-useful: (t) ->
        switch t.tag
            | 'style' => false
            | otherwise
                not t.original?
                or not t.resolved?
                or not /^http/.test t.resolved
                or t.resolved.slice(-1) == '/'
                or url.parse t.original .hostname in config.CDN_HOSTS

    load-task-list: ($) ->
        task-list = []
        $ 'a'                    .each -> task-list.push new FileTask org.uri, $(this), 'anchor', 'href'
        $ 'script[src*=js]'      .each -> task-list.push new FileTask org.uri, $(this), 'script', 'src'
        $ 'img:not([src^=data])' .each -> task-list.push new FileTask org.uri, $(this), 'img', 'src'
        # https://developer.mozilla.org/en-US/docs/Web/HTML/Link_types
        $ 'link[rel*=icon]'      .each -> task-list.push new FileTask org.uri, $(this), 'img', 'href'
        $ 'link[rel=stylesheet]' .each -> task-list.push new FileTask org.uri, $(this), 'css', 'href'
        $ 'style[src!=""]'       .each -> task-list.push new FileTask org.uri, $(this), 'style-x', ''
        reject @not-useful, task-list
        
    process-css-buffer: (t, body, cb) ->
        # console.log "process-css-buffer: #{t.to-string!}"
        obj = css.parse body.toString!, silent: true, source: t.referer
        return cb null unless obj.stylesheet?
        return cb null unless obj.stylesheet.rules?
        err <~ @process-decl-list t, obj
        return cb err if err?
        # Broken.  Take it out of the mix.  Really remove later...
        # err <~ @process-import-list t, obj
        # return cb err if err?
        try
            # console.log "process-css-buffer: stringifying the CSS, #{t.resolved}"
            return cb null, css.stringify obj
        catch thrown
            console.log "process-css-buffer: #{t.resolved}"
            console.log "process-css-buffer: css.stringify error #{thrown}"
            return cb null, body

    process-css-file-task: (t, cb) ~>
        # console.log "process-css-file-task: #{t.to-string!}"
        (err, body) <~ t.read-resolved
        return cb err if err?
        return cb null unless body?
        (err, body) <~ @process-css-buffer t, body
        #return cb err if err?
        return cb null unless body?
        t.save-buffer-to-disk body, cb

    # Method to handle "url(" in a declaration.
    process-decl-list: (t, obj, cb) ->
        # console.log "process-decl-list: #{t.to-string!}"
        # obj.stylesheet.rules.forEach (e) -> console.log e
        decls = obj.stylesheet.rules
            |> map (.declarations)
            |> flatten
            |> compact
            |> filter (declaration) -> /url/.test declaration.value
        tasks = decls.map (it) -> new DeclTask t.resolved, it, '', ''
        err <~ async.each tasks, (t, cb) -> t.save-url-to-disk cb
        return cb err if err?
 
        decls = obj.stylesheet.rules
            |> map (.import)
            |> flatten
            |> compact
            |> filter (declaration) -> /url/.test declaration.value
        # console.log "decls", decls
        tasks = decls.map (it) -> new DeclTask t.resolved, it, '', ''
        err <~ async.each tasks, (t, cb) -> t.save-url-to-disk cb
        return cb err       

    process-style-task: (t, cb) ->
        # console.log "process-style-task: #{t.to-string!} parsing #{t.elem.html().length} bytes of embedded CSS, \n#{t.elem.html!}\n"
        (err, body) <- @process-css-buffer t, t.get-html!
        return cb err if err?
        return cb null unless body?
        t.set-html body
        cb null

    process-task-list: (t, cb) ~>
        # console.log "process-task-list: original is" t.original
        switch t.tag
            | \anchor => t.store-filename!; cb null
            | \style => @process-style-task t, cb
            | \css => @process-css-file-task t, cb
            | otherwise => t.save-url-to-disk cb

    read-html: (t, cb) ->      
        if org.filename?
            err, body <~ fs.readFile org.filename, encoding: \utf8
            # console.log "run: retrieved #{body.length} bytes from #{org.filename}"
            cb err, body
        else
            err, body <~ t.read-resolved
            return cb err, body unless body?
            # console.log "run: retrieved #{body.length} bytes from #{org.uri}"
            cb err, body

    run: (cb) ->
        t = new HtmlTask org.uri, '', '', ''
        (err, body) <~ @read-html t
        return cb err if err?
        # body2 = body.to-string!
            # .replace(/\&apos;/gm, '"')
            # .replace(/@/gm, "\n    @")
            # .replace(/<\!--.+?-->/gm, '')
            # .replace(/<\!--.+?-->/gm, '')
        $ = cheerio.load body.to-string!, 'utf-8'
        e = $ org.tag-selector
        switch e.length
        | 0 => return cb "tag selector '#{org.tag-selector}' does not identify a node"
        | 1 =>
        | otherwise => return cb console.log "tag selector '#{org.tag-selector}' identifies #{e.length} nodes, must only identify one."

        e.empty! .append config.TEMPLATE_TAGS
        task-list = @load-task-list $
        # console.log "run: task list contains #{task-list.length} tasks"
        err <- async.each task-list, @process-task-list
        console.log "run: process-task-list returned err", err if err?
        return cb err if err?
        t.save-buffer-to-disk $.html!, cb

new Extractenator9000().run (err) ->
    console.log err, "on", org.uri if err?
    process.exit 0
