require! {
    async
    css
    'prelude-ls': { compact, each, filter, flatten, map } 
    './handlers/file': { FileHandler }
}

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
        handler = new FileHandler @referer, rule, attr
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
