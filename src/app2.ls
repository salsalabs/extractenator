require! {
    cheerio
    async
    './config'
    css
    'fs-extra': fs
    path
    'prelude-ls': { compact, each, filter, flatten, map } 
    request
    url
    './org': { Org }
}

# Base class that resolves an element's contents using the org's URi
# then updates the element.
class AnchorHandler
    # Class variable to contain a serial number for file disambiguation.
    @serial-number = 0
    # Class variable to cache URIs so that they are only processed once
    @uri-cache = {}

    (@referer, @elem, @attr) ->
        @content-type = null
        @org = new Org()
        @resolved = null
        @url-object = null
        @uri = @get-uri!

    # @return returns the filename part of the basename.  No extra junk.
    clean-basename: (v) -> v .split /[\?\&\;\#]/ .0

    # @return returns the basename for the URI.
    get-basename: ->
        basename = (path.basename @resolved .split '?')[0]
        return @clean-basename basename if path.extname basename .length > 0
        extension = (@content-type .split '/' .1)
        return @clean-basename "#{basename || ++@@serial-number}.#{extension}"

    # @return determine the directory where the file should live.  Directories
    # are chosen based on the Content_Type from the HTTP headers.
    get-directory: ->
        | /image\//.test @content-type => \image
        | /css/.test @content-type => \css
        | /javascript/.test @content-type => \javascript
        | /font/.test @content-type => \font
        | otherwise ''

    # Retrieve the URI's protocol.  Used in deciding how to read the URI
    # and where to store the URI contents.
    get-protocol: ->
        @url-object = url.parse @get-uri! unless @url-object?
        @url-obj.protocol

    # @return  Resolve the current URI against the site URL or the current
    # referer.  This should make for clean URIs in `fetch`
    get-resolved: ->
        return @@uri-cache[@uri] if @uri in @@uri-cache
        url-obj = url.parse @uri
        return @uri if url-obj.host in config.CDN_HOSTS
        return @uri if @get-protocol! == 'data'
        referer = switch @referer | null =>@org.uri | otherwise => @referer
        try unless @get-protocol!?
            @resolved = url.resolve @referer, @uri
        catch thrown
            console.error "URL.resolve threw #{thrown}"
            console.error "referer is #{@referer}"
            console.error "original is #{@uri}"
            console.error "\n"
            @resoived = @url

        @uri-cache[@uri] = @resolved
        @resolved

    # @return returns the current URI.  Override this if your class does
    # not need a URI in an element.
    get-uri: -> @elem .attr @attr

    # Worker bee.  Gets the resolved filename and stores it.  Override this
    # to add any I/O in your subclass.
    # @param  [Function]  cb  callback to handle (err)
    run: (cb) ->
        @get-resolved!
        @store-filename!

    # Store the filename in the element instance variable.  Override this
    # method if there's not an element.
    store-filename: -> @elem .attr @attr = @filename

# Override base class to retrieve a file's contents and save it
class FileHandler extends AnchorHandler
    # Retrieve the contents of the instance URI.  A null is returned if
    # the URI fails or the returned contents are empty.  If the HTTP status
    # code is not 200 (success), then the buffer from the website is
    # returned.
    # @param  [Function]  cb  callback to handle (cb, buffer)
    fetch: (cb) ->
        cb null, null if @get-protocol! == 'data'
        (err, resp, body) <~ @request @resolved!
        if err?
            console.err "fetch caught #{err} on {#@resolved!}"
            return cb null, null
        @content-type = resp.headers.'content-type'
        return cb null, body if resp.status-code == 200
        cb null, null

    # Fetch a file, store it in the directory, then store the new filename in the
    # element instance variable.
    # @param  [Function]  cb  callback to handle (null).
    run: (cb) ->
        (err, buffer) <- @fetch!
        console.error "Handler: #{err} while fetching #{@resolved}" if err?
        return cb null if err?
    
        console.error "Handler: empty buffer while fetching #{@resolved}" unless buffer?
        return cb null unless buffer?
    
        (err, buffer) <- @transform buffer
        console.error "Handler: #{err} while transforming #{@resolved}" if err?
        return cb null if not buffer?
    
        (err) <- @save buffer
        console.error "Handler: #{err} while saving #{@resolved}" if err?
        return cb null if err?

        @store-filename!
        console.log "Handler: saved @filename"
        cb null

    # Instalce variable to return the `request` instance used in this class.
    # The `request` instance contains Referer, User-Agent and cookies.
    request: request.defaults do
        jar: true
        encoding: null
        headers:
            'Referer':@org.uri
            'User-Agent': config.USER_AGENT    

    # Store the provided `buffer` using the content-type and the file's
    # basename.
    # @param  [Buffer|String] buffer contents to save
    # @param  [Function]      cb     callback to handle (err)
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

        err <~ fs.writeFile local-filename, buffer, encoding: null
        return cb err

    # Method to transform and return the contents of the provilded `buffer`.
    # The defuault behavior is to return `buf` without modification.
    # @param  [Buffer|String]  buffer  buffer to writeto write
    # @param  [Function]       cb      callback to handle (err, modifiedBuffer)
    transform: (body, cb) -> cb null, body

# Override base class to parse contents as CSS and store a file.
class CSSHandler extends FileHandler

    # Override to parse `body` for @font-face and @import tags.  Both of these
    # declarations contain `url()` parameters.  The URL values need to be
    # retrieved and stored locally.
    # @param  [String]    body  CSS content to modify
    # @param  [Function]  cb    callback to handle (cb, parsedBody)
    transform: (body, cb) ->
        try
            css-obj = css.parse body.toString!, silent: true, source: @referer
            return cb null, body unless css-obj.stylesheet?
            return cb null, body unless css-obj.stylesheet.rules?
            decls = css-obj.stylesheet.rules
                |> map (.declarations)
                |> flatten
                |> compact

            value-decls = decls |> filter @validate-value
            if value-decls.length > 0
                err <~ async.each decls, @transform-decl
                if err?
                    console.log "CSSHandler: transform #{err}"
                    return cb null, body
                return cb null, css.stringify css-obj

            import-decls = decls |> filter @validate-import
            if decls.length > 0
                err <~ async.each decls, @transform-import
                if err?
                    console.log "CSSHandler: transform #{err}"
                    return cb null, body
                return cb null, css.stringify css-obj
 
        catch thrown
            console.error "transform-css-buffer: caught css.stringify error #{thrown}"
            return cb null, body

    # Common CSS element handler.
    # @param  [Object]    rule  the CSS rule of interest
    # @param  [String]    attr  attribute to examine for a URL
    # @param  [Function]  cb    Callback to accept (err)
    transform-common: (rule, attr, cb) ->
        return cb null unless @attr in rule
        handler = new FileHandler (@uri or @referer), rule, attr
        (err) <- handler.run!
        console.error "CSSHandler: #{err} while saving #{@handler.resolved}" if err?
        return cb err if err?
        console.log "CSSHander: saved #{handler.filename}"
        return cb null

    # Transform a 'declaration' used by @font-face
    # @param  [Object]    rule  the CSS rule of interest
    # @param  [Function]  cb    Callback to accept (err)
    transform-decl: (rule, cb) -> @transform-common rule, \value, cb

    # Transform an @option rule
    # @param  [Object]    rule  the CSS rule of interest
    # @param  [Function]  cb    Callback to accept (err)
    transform-import: (rule, cb) -> @transform-common rule, \import, cb
    
    # Return true if the @import contains a URL
    # @param  [Object]    rule  the CSS rule of interest
    validate-import: (rule) -> rule.property == \src
    
    # Return true if the @font-face contains a URL (typically it does...)
    # @param  [Object]    rule  the CSS rule of interest
    validate-value: (rule) -> /url/.test rule.option

# Override base class to store CSS back in the element (not in a file)
class StyleHandler extends CSSHandler
    fetch: (cb) -> cb null, @elem .html!
    save: (buffer, cb) -> @elem .html buffer ; cb null
    store-filename: ->

# Override base class to parse HTML, store the template tags and process
# read, transform and store the DOM.
class HTMLHandler extends FileHandler

    # Override to process an HTML file.  Elements that may contain URLs to site
    # files are read and processed.  Things like images and scripts are read 
    # and stored.  CSS is parsed for URLs.  Those are read and stored.
    transform: (body, cb) ->
        $ = cheerio.load body.to-string!, 'utf-8'
        e = $ @org.tag-selector
        switch e.length
        | 0 => return cb "tag selector '#{@org.tag-selector}' does not indentify a node"
        | 1 =>
        | otherwise => return cb console.log "tag selector '#{@org.tag-selector}' identifies #{e.length} nodes, must only identify one."
        e.empty! .append config.TEMPLATE_TAGS

        task-list = []
        $ 'a'                    .each -> task-list.push new AnchorHandler  @org.uri, $(this), 'href'
        $ 'img:not([src^=data])' .each -> task-list.push new FileHandler  @org.uri, $(this), 'src'
        $ 'link[rel*=icon]'      .each -> task-list.push new FileHandler  @org.uri, $(this), 'href'
        $ 'link[rel=stylesheet]' .each -> task-list.push new CSSHandler   @org.uri, $(this), 'href'
        $ 'script[src*=js]'      .each -> task-list.push new FileHandler  @org.uri, $(this), 'src'
        $ 'style'                .each -> task-list.push new StyleHandler @org.uri, $(this), null
 
        (err) <- async.each task-list, (t) -> t.run
        console.log "run: process-task-list returned err", err if err?
        return cb err, body if err?
        cb null, $.html!

# Override the base class to retrieve HTML from an org and process it fully.
class Extractenator9000 extends HTMLHandler
    () ->
        @org = new Org()
        super @org.uri, null, null
        @content-type = ''

    # Override to use the URI from the org record as the resolved URL.
    get-resolved: -> @org.uri

    # Override to use the URI in the Org record.
    get-uri: -> @org.uri
    
    # Override to not store the filename in a structure.
    store-filename: ->

# Application starts here.
(err) <- new Extractenator9000().run
console.error err, "on", @org.uri if err?
process.exit 0
