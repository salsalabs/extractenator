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
        @_localRequest = request.defaults options
        @registry = {}
        @_serialNumber = 0

    # @property [Object]  Returns the `request` object to use when reading from
    # the source website.  The request object has default behavior predefined
    # that avoids problems that the COSM extractor has regularly:
    # * A `User-Agent` value is provided in the headers
    # * The `Referer` header value is defaults to the URI in `@opts`
    # * Cookies are handled properly
    # The net effect is that this extractor should work a lot better than the
    # current COSM template extractor.
    #
    get localRequest: -> @_localRequest

    # @property [String] returns the next registry key
    #
    get nextRegistryKey: -> "f#{@_serialNumber++}"

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
        return parts[1] if parts[1] in ['javascript', 'css']
        return 'image' if parts[1] in [ 'octet-stream' ]
        return contentType
        
    # Returns true if the provide `uri` is for a known CDN host. This includes any
    # `uri` that starts with '//' or whose hostname is in the known CDN host list.
    #
    # @param    [String]  uri  URI to test
    # @return   [Boolean]  returns true if the uri is for a known CDN host
    #
    isCdn: (u) ->
        return true if RegExp('^(https)*//').test u
        r = url.parse u
        return r.hostname in config.CDN_HOSTS

    # Write a URL to disk.  The file is stored in the provided directory using the
    # content type returned from the read.
    #
    # @param  [String]    uri  URL (possibly relative) to write
    # @param  [Function]  cb   callback to  handle (`err`, `outputPath`)
    #
    # @note This is an improvement over the Salsa extractor.  We provide a referer
    # and manage cookies for all requests for files.
    #
    saveUrl: (uri, cb) ->
        @debug "Base.saveUrl: saving #{uri}"
        return cb null, null unless uri?
        return cb null, null unless path.basename(uri)?.length > 0
        uri = url.resolve @opts.url, uri unless RegExp('^http').test uri
        readRequest = @localRequest.defaults encoding:null
        @debug "Base.saveUrl: #{uri} is resource URI"
        readRequest uri, (err, resp, body) =>
            return cb err, null if err?
            @debug "Base.saveUrl: #{uri} returned status code #{resp.statusCode}"
            @debug "Base.saveUrl: #{uri} returned status #(resp.statusCode}"
            return cb null, @opts.url unless resp.statusCode == 200
            contentType = resp.headers['content-type'].split(';')[0]
            @debug "Base.saveUrl: #{uri} has content type #{contentType}"
            return cb null, uri unless @validContentType contentType
            subdir = @getSubdir contentType
            @debug "Base.saveUrl: #{uri} has subdir #{subdir}"
            filename = path.join(subdir, path.basename(uri)).split('?')[0]
            @debug "Base.saveUrl: #{uri} has filename #{filename}"
            if @needsContentModification contentType
                @debug "Base.saveUrl: #{uri} calling modifyContent"
                @modifyContent contentType, body, (err, b) =>
                    @debug "Base.saveUrl: #{uri} modifyContent returned error #{err}"
                    return cb err, null if err?
                    @debug "Base.saveUrl, saving #{filename}"
                    @writeFile filename, b
            else
                @writeFile filename, body
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
        return true if parts[0] in ['image', 'video']
        return false if parts[0] not in ['application', 'text']
        return parts[1] not in ['html']

    # Return the "marker" that mustache needs for a registry key.  The marker
    # the Mustache delimiters to interpret the value for the registry key as a
    # literal.  The registry key forces the directory to be the one provided
    # in the `opts` parameter to the constructor.
    #
    # @params [String] registryKey  registry key to wrap
    # @return [String] Returns the wrapped registry key
    #
    wrapRegistryKey: (registryKey) ->
        "#{@opts.dir}/{{{#{registryKey}}}}"

    # Write a file to the output directory.  This method accepts a filename,
    # recursively creates a subdirectories, then writes the file.
    #
    # @param  [String]         filename  filename where `content` ends up
    # @param  [String, Buffer] content  content to write to `filename`
    # @throws [Error]  Errors are thrown by underlying call, `fs.writeFileSync`
    #
    writeFile: (filename, content) ->
        filename = path.join(@opts.dir, filename)
        wrench.mkdirSyncRecursive path.dirname filename
        fs.writeFile filename, content, (e) -> 
            console.log("Error #{e} writing #{filename}") if e?

module.exports =
    Base: Base
