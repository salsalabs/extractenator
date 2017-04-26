require! {
    '../config'
    css
    path
    request
    url
    '../org': { Org }
}

# Base class that resolves an element's contents using the org's URi
# then updates the element.
export class AnchorHandler
    # Class variable to contain a serial number for file disambiguation.
    @serial-number = 0
    # Class variable to cache URIs so that they are only processed once
    @uri-cache = {}

    (@referer, @elem, @attr) ->
        @content-type = null
        @org = new Org()
        @url-object = null
        @uri = @get-uri!
        console.log "AnchorHandler(): @uri is #{@uri}"

    # @return returns the filename part of the basename.  No extra junk.
    clean-basename: (v) -> v .split /[\?\&\;\#]/ .0

    # @return returns the basename for the URI.
    get-basename: ->
        basename = (path.basename @get-resolved! .split '?')[0]
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

    # @return  [Object]  Organization object
    # Retrieve the URI's protocol.  Used in deciding how to read the URI
    # and where to store the URI contents.
    get-protocol: ->
        @url-object = url.parse @get-uri! unless @url-object?
        @url-object.protocol

    # @return  Resolve the current URI against the site URL or the current
    # referer.  This should make for clean URIs in `fetch`
    get-resolved: ->
        return @@uri-cache[@uri] if @uri in @@uri-cache
        url-obj = url.parse @uri
        return @uri if url-obj.host in config.CDN_HOSTS
        return @uri if @get-protocol! == 'data'
        referer = switch @referer | null => @org.uri | otherwise => @referer
        try unless @get-protocol!?
           resolved = url.resolve @referer, @uri
        catch thrown
            console.error "URL.resolve threw #{thrown}"
            console.error "referer is #{@referer}"
            console.error "original is #{@uri}"
            console.error "\n"

        @@uri-cache[@uri] = resolved
        resolved

    # @return returns the current URI.  Override this if your class does
    # not need a URI in an element.
    get-uri: -> @elem .attr @attr

    # Worker bee.  Gets the resolved filename and stores it.  Override this
    # to add any I/O in your subclass.
    # @param  [Function]  cb  callback to handle (err)
    run: (cb) ->
        console.log "Anchor.run: uri is #{@uri}, resolved is #{@get-resolved!}"
        #if @get-resolved!? 
        @filename = @get-resolved! or @uri
        @store-filename!
        # console.log "Anchor:run @filename is #{@get-resolved!}"
        cb null

    # Store the filename in the element instance variable.  Override this
    # method if there's not an element.
    store-filename: -> @elem .attr @attr, @get-resolved!