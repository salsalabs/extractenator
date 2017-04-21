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
        @uri = @elem[@attr]

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

    run: (cb) ->
        (err, buffer) <- @fetch!
        console.error "Handler: #{err} while fetching #{@resolved}" if err?
        return cb null if err?
    
        console.error "Handler: empty buffer while fetching #{@resolved}" unless buffer?
        return cb null unless buffer?
    
        (err, buffer) <- @transform body
        console.error "Handler: #{err} while transforming #{@resolved}" if err?
        return cb null not buffer?
    
        (err) <- @save buffer
        console.error "Handler: #{err} while saving #{@resolved}" if err?
        return cb null if err?
        
        @elem[@attr] = @filename
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
        @filename = path.join org.dir, @get-directory!, @get-basename!
        local-filename = switch @filename.slice 0 1
            | '/' => @filename.slice 1
            | otherwise => @filename
        target-dir = path.dirname local-filename
        err <~ fs.mkdirs target-dir
        console.error "save-buffer-to-dir mkdirs returned #err" if err?
        return cb null if err?

        err <~ fs.writeFile local-filename, body, encoding: null
        return cb err

    transform: (body, cb) -> cb null, body

class CSSHandler extends Handlers
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

    transform-common: (rule, attr, cb) ->
        return cb null unless @attr in rule
        handler = new Handler (@uri or @referer), rule, attr
        (err) <- handler.run!
        console.error "CSSHandler: #{err} while saving #{@handler.resolved}" if err?
        return cb err if err?
        console.log "CSSHander: saved @filename"
        return cb null


    transform-decl: (rule, cb) -> transform-common rule, \value, cb
    transform-import: (rule, cb) -> transform-common rule, \import, cb
    validate-import: (e) -> e.property == \src
    validate-value: (e) -> /url/.test e.option
