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

    # Return the "marker" that mustache needs for a registry key.  The marker
    # contains the directory name and the Mustache delimiters to interpret the
    # value for the registry key as a literal.
    #
    # @example
    # ```
    # @opts.dir
    # `DIRECTORY`
    # @nextReistryKey 'f32'
    # `/DIRECTORY/{{{f32}}}`
    # ```
    #
    # @params [String] registryKey  registry key to wrap
    # @return [String] Returns the wrapped registry key
    #
    wrapRegistryKey: (registryKey) ->
        "/#{@opts.dir}/{{{#{registryKey}}}}"

    # Returns true if the provide `uri` is for a known CDN host. This includes any
    # `uri` that starts with '//' or whose hostname is in the known CDN host list.
    #
    # @param    [String]  uri  URI to test
    # @return   [Boolean]  returns true if the uri is for a known CDN host
    #
    isCdn: (u) ->
        return true if RegExp('^//').test u
        r = url.parse u
        return r.hostname in config.CDN_HOSTS

    # Method to modify a URI's contents before it is written to disk.  Override
    # this method if a buffer needs to be changed for some reason before it's
    # saved to disk.
    #
    # @param  [String]    contentType  HTTP content type, for example `text/css'
    # @param  [Buffer]    body         the contents to modify
    # @param  [Function]  cb           callback to handle (`err`, 'modifiedBody`)
    #
    # @note Default behavior is to call `cb null, body`
    #
    modifyContent: (contentType, body, cb) -> cb null, body

    # Returns true if the contents of a URL with the provided `contentType` needs
    # to be modified before being written to disk.
    #
    # @param  [String]    contentType  HTTP content type, for example `text/css'
    # @return [Boolean]  returns true of the provided `contentType` needs to be modified
    #
    # @note Default behavior is to return `false`.
    #
    needsContentModification: (contentType) -> false

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
        return cb null, null unless uri?
        return cb null, null unless path.basename(uri)?.length > 0
        unless RegExp('^http').test uri
            r = url.parse @opts.url
            r.pathname = uri
            uri = url.format r
        saveRequest = @localRequest.defaults encoding:null
        saveRequest uri, encoding:null, (err, resp, body) =>
            return cb err, null if err?
            return cb resp.statusCode, @opts.url unless resp.statusCode == 200
            contentType = resp.headers['content-type'].split(';')[0]
            return cb null, uri unless @validContentType contentType
            filename = path.join contentType, path.basename(uri)
            filename = filename.split('?')[0]
            if @needsContentModification contentType
                @modifyContent contentType, body, (err, b) =>
                    return cb err, null if err?
                    console.log "Base.saveUrl, saving #{filename}"
                    @writeFile filename, b
                    cb null, filename
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
        fs.writeFileSync filename, content

module.exports =
    Base: Base
