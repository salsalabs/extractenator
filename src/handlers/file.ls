require! {
    '../config'
    'fs-extra': fs
    path
    request
    './anchor': { AnchorHandler }
}

# Override base class to retrieve a file's contents and save it
export class FileHandler extends AnchorHandler
    # Retrieve the contents of the instance URI.  A null is returned if
    # the URI fails or the returned contents are empty.  If the HTTP status
    # code is not 200 (success), then the buffer from the website is
    # returned.
    # @param  [Function]  cb  callback to handle (cb, buffer)
    fetch: (cb) ->
        cb null, null if @get-protocol! == 'data'
        (err, resp, body) <~ @request @resolved
        if err?
            console.err "fetch caught #{err} on {#@resolved}"
            return cb null, null
        @content-type = resp.headers.'content-type'
        return cb null, body if resp.status-code == 200
        cb null, null

    # Instance variable to return the `request` instance used in this class.
    # The `request` instance contains Referer, User-Agent and cookies.
    request: -> request.defaults do
        jar: true
        encoding: null
        headers:
            'Referer': @org.uri
            'User-Agent': config.USER_AGENT    

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
