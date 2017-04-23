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

class FileHandler
    @serial-number = 0
    @uri-cache = {}

    (@referer, @elem, @attr) ->
        @content-type = null
        @org = new Org()
        @protocol = null
        @resolved = null
        @uri = @get-uri!

    clean-basename: (v) -> v .split /[\?\&\;\#]/ .0

    # returns (err, body)
    fetch: (cb) ->
        cb null, null if @protocol == 'data'
        (err, resp, body) <~ @request @resolved!
        if err?
            console.err "fetch caught #{err} on {#resolved!}"
            return cb null, null
        @content-type = resp.headers.'content-type'
        return cb null, body if resp.status-code == 200
        cb null, null

    get-basename: ->
        basename = (path.basename @resolved .split '?')[0]
        return @clean-basename basename if path.extname basename .length > 0
        extension = (@content-type .split '/' .1)
        return @clean-basename "#{basename || ++@@serial-number}.#{extension}"

    get-directory: ->
        | /image\//.test @content-type => \image
        | /css/.test @content-type => \css
        | /javascript/.test @content-type => \javascript
        | /font/.test @content-type => \font
        | otherwise ''

    get-resolved: ->
        return @uri-cache[@uri] if @uri in @uri-cache

        url-obj = url.parse @uri
        return @uri if url-obj.host in config.CDN_HOSTS
        @protocol = url-obj .protocol
        return @uri if @protocol == 'data'
        referer = switch @referer | null =>@org.uri | otherwise => @referer
        try unless @protocol?
            @resolved url.resolve @referer, @uri
        catch thrown
            console.error "URL.resolve threw #{thrown}"
            console.error "referer is #{@referer}"
            console.error "original is #{@uri}"
            console.error "\n"
            @resoived = @url

        @uri-cache[@uri] = @resolved
        @resolved

    get-url: -> @elem .attr @attr

    run: (cb) ->
        (err, buffer) <- @fetch!
        console.error "Handler: #{err} while fetching #{@resolved}" if err?
        return cb null if err?
    
        console.error "Handler: empty buffer while fetching #{@resolved}" unless buffer?
        return cb null unless buffer?
    
        (err, buffer) <- @transform body
        console.error "Handler: #{err} while transforming #{@resolved}" if err?
        return cb null if not buffer?
    
        (err) <- @save buffer
        console.error "Handler: #{err} while saving #{@resolved}" if err?
        return cb null if err?
        @store-filename!
        console.log "Handler: saved @filename"
        cb null

    request: request.defaults do
        jar: true
        encoding: null
        headers:
            'Referer':@org.uri
            'User-Agent': config.USER_AGENT    

    save: (buffer, cb) ->
        # console.error "save-buffer-to-disk: #{@to-string!}"
        @filename = path.join @org.dir, @get-directory!, @get-basename!
        local-filename = switch @filename.slice 0 1
            | '/' => @filename.slice 1
            | otherwise => @filename
        target-dir = path.dirname local-filename
        err <~ fs.mkdirs target-dir
        console.error "save-buffer-to-dir mkdirs returned #err" if err?
        return cb null if err?

        err <~ fs.writeFile local-filename, body, encoding: null
        return cb err

    store-filename: -> @elem .attr @attr = @filename

    transform: (body, cb) -> cb null, body

# Override base class to parse as CSS and store a file.
class CSSHandler extends FileHandler

    # Override to parse `body` for @font-face and @import tags
    transform: (body, cb) ->
        try
            css-obj = css.parse body.toString!, silent: true, source: @referer
            return cb null, body unless css-obj.stylesheet?
            return cb null, body unless css-obj.stylesheet.rules?
            decls = css-obj.stylesheet.rules
                |> map (.declarations)
                |> flatten
                |> compact

            value-decls = decls |> filter validate-value
            if value-decls.length > 0
                err <~ async.each decls, @transform-decl
                return cb null, css.stringify obj

            import-decls = decls |> filter validate-import
            if decls.length > 0
                err <~ async.each decls, @transform-import
                return cb null, css.stringify obj
 
        catch thrown
            console.error "transform-css-buffer: caught css.stringify error #{thrown}"
            return cb null, body

    # Common CSS element handler.
    # @param  [Object]    rule  the CSS rule of interest
    # @param  [String]    attr  attribute to examine for a URL
    # @param  [Function]  cb    Callback to accept (err)
    transform-common: (rule, attr, cb) ->
        return cb null unless @attr in rule
        handler = new Handler (@uri or @referer), rule, attr
        (err) <- handler.run!
        console.error "CSSHandler: #{err} while saving #{@handler.resolved}" if err?
        return cb err if err?
        console.log "CSSHander: saved #{handler.filename}"
        return cb null

    # Transform a 'declaration' used by @font-face
    # @param  [Object]    rule  the CSS rule of interest
    # @param  [Function]  cb    Callback to accept (err)
    transform-decl: (rule, cb) -> transform-common rule, \value, cb

    # Transform an @option rule
    # @param  [Object]    rule  the CSS rule of interest
    # @param  [Function]  cb    Callback to accept (err)
    transform-import: (rule, cb) -> transform-common rule, \import, cb
    
    # Return true if the @import contains a URL
    # @param  [Object]    rule  the CSS rule of interest
    validate-import: (rule) -> rule.property == \src
    
    # Return true if the @font-face contains a URL (typically it does...)
    # @param  [Object]    rule  the CSS rule of interest
    validate-value: (rule) -> /url/.test rule.option

# Override base class to store CSS back in the element (not in a file)
class StyleHandler  extends CSSHandler
    fetch: (cb) -> cb null, @elem .html!
    save: (buffer, cb) -> @elem .html buffer ; cb null
    store-filename: ->

# Override base class to parse HTML
class HTMLHandler extends FileHandler

    # Override to process an HTML file.  Selected elements are either saved
    # to disk or CSS-parsed and then saved to disk.
    transform: (body, cb) ->
        $ = cheerio.load body.to-string!, 'utf-8'
        e = $ org.tag-selector
        switch e.length
        | 0 => return cb "tag selector '#{@org.tag-selector}' does not indentify a node"
        | 1 =>
        | otherwise => return cb console.log "tag selector '#{@org.tag-selector}' identifies #{e.length} nodes, must only identify one."
        e.empty! .append config.TEMPLATE_TAGS

        task-list = []
        $ 'a'                    .each -> task-list.push new FileHandler  @org.uri, $(this), 'href'
        $ 'img:not([src^=data])' .each -> task-list.push new FileHandler  @org.uri, $(this), 'src'
        $ 'link[rel*=icon]'      .each -> task-list.push new FileHandler  @org.uri, $(this), 'href'
        $ 'link[rel=stylesheet]' .each -> task-list.push new CSSHandker   @org.uri, $(this), 'href'
        $ 'script[src*=js]'      .each -> task-list.push new FileHandler  @org.uri, $(this), 'src'
        $ 'style'                .each -> task-list.push new StyleHandler @org.uri, $(this), null
 
        err <- async.each task-list, @process-task-list
        console.log "run: process-task-list returned err", err if err?
        return cb err, body if err?
        cb null, $.html!

# Override to use data from the Org
class Extractenator9000 extends HTMLHandler
    () ->
        @org = new Org()
        super @org.uri, null, null

    # Override to store in the directory and not in a subdirectory.
    get-directory: -> ''

    # Override to use the URI in the Org record.
    get-uri: -> @org.uri
    
    # Override to not store the filename in a structure.
    store-filename: ->

# Application starts here.
(err) <- new Extractenator9000().run
    console.log err, "on", @org.uri if err?
    process.exit 0
