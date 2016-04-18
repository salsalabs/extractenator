config   = require './config'
fs       = require 'fs'
path     = require 'path'
request  = require 'request'
url      = require 'url'
wrench   = require 'wrench'

# Base class to provide common read, right and registration for the classes in
# this project.
#
class Base
    get = (props) => @::__defineGetter__ name, getter for name, getter of props
    set = (props) => @::__defineSetter__ name, setter for name, setter of props

    @registry = {}
    @_serialNumber = 0

    # Constructor.  Instantiates this class.
    #
    # @param         [Object]    opts  runtime parameters
    # @option  opts  [String]    url  URL to read
    # @option  opts  [String]    dir  directory to use for storing files
    #
    constructor: (@opts) ->
        options =
            jar: true
            encoding: 'utf8'
            headers:
                'Referer': @opts.url
                'User-Agent': config.USER_AGENT

        if @opts.authUsername?
            options.auth = 
                username: @opts.authUsername
                password: @opts.authPassword
                sendImmediately: false
        @_localRequest = request.defaults options

    # @property [Object]  Returns the `request` object to use when reading from
    # the source website.  The request object has default behavior predefined
    # that avoids problems that the Salsa Classic extractor has regularly:
    # * A `User-Agent` value is provided in the headers
    # * The `Referer` header value is defaults to the URI in `@optss`
    # * Cookies are handled properly
    # * The user can provide username/password to gain access to previews
    # The net effect is that this extractor should work a lot better than the
    # current Salsa Classic template extractor.
    #
    get localRequest: -> @_localRequest

    # @property [String] returns the next registry key
    #
    get nextRegistryKey: -> "f#{Base._serialNumber++}"

    # Display `message` onto the console if the global `debug` flag is set.
    #
    # @param  [String]  message  @debug message to display
    #
    debug: (message) ->
        console.log message if @opts.debug?
        
    # Examine a content type and return the directory where the content should
    # be stored.
    #
    # @param   [String]  contentType  standard HTTP content type
    # @return  [String]  directory name
    #
    getSubdir: (contentType) ->
        parts = contentType.split '/'
        parts[1] = 'javascript' if parts[1] in ['x-javascript']
        return parts[0] if parts[0] in ['image', 'video']
        return parts[1] if parts[1] in ['javascript', 'css', 'font']
        return 'image' if parts[1] in [ 'octet-stream' ]
        return contentType
        
    # Returns true if the provide `uri` is for a known CDN host. This includes any
    # `uri` that starts with '//' or whose hostname is in the known CDN host list.
    #
    # @param    [String]  uri  URI to test
    # @return   [Boolean]  returns true if the uri is for a known CDN host
    #
    isCdn: (u) ->
        r = url.parse u
        return r.hostname in config.CDN_HOSTS

    # Returns true if the contents of a URL with the provided `contentType` needs
    # to be modified before being written to disk.
    #
    # @param  [String]   contentType  HTTP content type, for example `text/css'
    # @return [Boolean]  returns true of the provided `contentType` needs to be modified
    #
    # @note Returns `false` by default;
    #
    needsContentModification: (contentType) -> false

    # Add a number to the file part of a filename.
    # @param  [String]  filename  filename of interest
    # @return [String]  returns the filename as `filename-count[.ext]`
    nextFilename: (filename) ->
        return filename unless filename?.length > 0
        ext = path.extname filename
        if (ext.length == 0)
            front = filename
        else
            front = filename.slice 0, filename.indexOf ext 
        m = /^(.+)-(\d+)$/.exec front
        return "#{front}-1#{ext}" unless m?
        count = 1 + parseInt m[2]
        "#{m[1]}-#{count}#{ext}"

    # Write a URL to disk.  The file is stored in the provided directory using the
    # content type returned from the read.
    #
    # @param  [String]    uri  URL (possibly relative) to write
    # @param  [Function]  cb   callback to  handle (`err`, `outputPath`)
    #
    # @note `outputPath` is null if `uri` is null or empty or ends in a slash
    #
    # @note This is an improvement over the Salsa extractor.  We provide a referer
    # and manage cookies for all requests for files.
    #
    saveUrl: (uri, cb) ->
        return cb null, null unless uri?
        return cb null, null unless path.basename(uri)?.length > 0
        return cb null, null unless uri.slice(-1) != '/'
        @debug "Base.saveUrl: saving #{uri}"
        uri = url.resolve @opts.url, uri unless RegExp('^http').test uri
        @debug "Base.saveUrl: saving resolved #{uri}"
        readRequest = @localRequest.defaults encoding:null
        @debug "Base.saveUrl: #{uri} is resource URI"
        readRequest uri, (err, resp, body) =>
            return cb err, null if err?
            @debug "Base.saveUrl: #{uri} has status code #{resp.statusCode}"
            return cb null, @opts.url unless resp.statusCode == 200
            contentType = resp.headers['content-type']
            unless contentType?
                console.log "Base.saveURL: Unknown content type for #{uri}, setting to 'text/html'"
                contentType = "text/html"
            @debug "Base.saveUrl: #{uri} has content type #{contentType}"
            contentType = contentType.split(';')[0]
            return cb null, uri unless @validContentType contentType
            subdir = @getSubdir contentType
            @debug "Base.saveUrl: #{uri} has subdir #{subdir}"
            filename = path.join(subdir, path.basename(uri)).split(/[\!\?]/)[0]
            @debug "Base.saveUrl: #{uri} has filename #{filename}"
            @debug "base.saveUrl: #{uri} has contentType #{contentType}. Will be modified? #{@needsContentModification contentType}"
            if @needsContentModification contentType
                @modifyContent uri, contentType, body, (err, b) =>
                    @debug "Base.saveUrl: #{uri} modifyContent returned err #{err} and #{b.length} character buffer"
                    return cb err, null if err?
                    @debug "Base.saveUrl, saving #{filename}"
                    filename = @writeFile filename, b
            else
                filename = @writeFile filename, body
            cb null, filename

    # Returns true if `contentType` is one of the content types that needs to
    # be saved.  This keeps us from saving HTML and other junk.
    #
    # @param   [String]  contentType  the content type to test
    # @return  [Boolean] returns true if the content type is one that needs to be saved
    #
    validContentType: (contentType) ->
        contentType = contentType.split(';')[0]
        parts = contentType.split('/')
        return false if parts[1] in ['json', 'rss+xml', 'xml', 'html']
        return true if parts[0] in ['image', 'video', 'application', 'text']

    # Return the "marker" that mustache needs for a registry key.  The marker
    # the Mustache delimiters to interpret the value for the registry key as a
    # literal.  The registry key forces the directory to be the one provided
    # in the `opts` parameter to the constructor.
    #
    # @params [String] registryKey  registry key to wrap
    # @return [String] Returns the wrapped registry key
    #
    wrapRegistryKey: (registryKey) ->
        "{{{#{registryKey}}}}"

    # Write a file to the output directory.  This method accepts a filename,
    # recursively creates a subdirectories, then writes the file.  If the
    # file already exists, then this method appends numbers to the filename
    # until there's not a match for the new filename.
    #
    # @param  [String]         filename  filename where `content` ends up
    # @param  [String, Buffer] content  content to write to `filename`
    # @return [String]         actual filename after de-duplication
    #
    writeFile: (filename, content) ->
        console.log "Base.writeFile writing #{filename}"
        unless content?.length > 0
            @debug "Base.writeFile: #{filename} is empty, skipping." unless content?.length > 0
            return null
        filename = path.join(@opts.dir, filename)
        working = true
        count = 1
        while working
            try
                fs.statSync filename
                @debug "Base.writeFile: #{filename} already exists"
                filename = @nextFilename filename, count++
                @debug "base.writeFile: Base.writeFile trying #{filename}"
            catch err
                working = false
        wrench.mkdirSyncRecursive path.dirname filename
        try
            fs.writeFileSync filename, content
            @debug "Base.writeFile wrote #{content.length} characters to #{filename}"
        catch e
            console.log "Base.writeFile #{err} on #{filename}" if err?
        @debug "Base.writeFile returning filename #{filename}"
        return filename

module.exports =
    Base: Base
