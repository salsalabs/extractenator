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
        console.log "File.fetch: attr is #{@attr}, elem is not null? #{@elem?} uri is #{@uri}, referer is #{@referer} resolved is #{@get-resolved!}"
        cb null, null if @get-protocol! == 'data'
        console.log "File: fetch:reading #{@get-resolved!}"

        (err, resp, body) <~ @request! .get @get-resolved!
        if err?
            console.error "fetch caught #{err} on #{@get-resolved!}" if err?
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
        console.log "File.run"
        (err, buffer) <~ @fetch!
        console.error "Handler: #{err} while fetching #{@get-resolved!}" if err?
        console.log "Handler: #{@resolved} yielded #{(buffer or []).length} bytes."
        return cb null if err?
    
        console.error "Handler: empty buffer while fetching #{@get-resolved!}" unless buffer?
        return cb null unless buffer?
    
        (err, buffer) <~ @transform buffer
        console.error "Handler: #{err} while transforming #{@get-resolved!}" if err?
        return cb null if not buffer?
    
        (err) <~ @save buffer
        console.error "Handler: #{err} while saving #{@get-resolved!}" if err?
        return cb null if err?

        @store-filename!
        # console.log "Handler: saved @filename"
        cb null

    # Store the provided `buffer` using the content-type and the file's
    # basename.
    # @param  [Buffer|String] buffer contents to save
    # @param  [Function]      cb     callback to handle (err)
    save: (buffer, cb) ->
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
