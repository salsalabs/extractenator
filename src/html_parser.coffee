_           = require 'underscore'
async       = require 'async'
config      = require './config'
jsdom       = require 'jsdom'
mustache    = require 'mustache'
{Base}      = require './base'
{CSSParser} = require './css_parser'

# Class to extract a Salsalabs COSM template from the URL provided in the
# calling arguments.  A directory is used to cache the files needed by the
# extracted template.  When all files are retrieved and corrected then they
# are moved into a directory on Salsa.  The template itself fis inserted into
# the `template` COSM database.
#
class HTMLParser extends Base
    # Constructor.  Instantiates this class using the provided runtime
    # parameters.
    #
    # @param         [Object]  opts  object containing runtime parameters
    # @option  opts  [Object]  url   the url to parse
    # @option  opts  [String]  dir   directory for storing files
    #
    constructor: (@opts) ->
        super @opts

    # Typically, the last step is to use Mustache to convert the modified
    # contents of the website to a template using the local files.  Doing that
    # causes all of the file to be relative URLs, making it easy for COSM to use
    # them after they are uploaded.
    #
    # @param  [String]    window    window object to save
    # @param  [Function]  cb        callback to handle (`err`)
    #
    finalize:  (window, cb) ->
        @writeFile 'registry.json', JSON.stringify(@registry, null, '    ')
        template = jsdom.serializeDocument window.document
        @writeFile 'working_template.html', template
        @writeFile 'template.html', mustache.render(template, @registry)
        cb null

    # Method to modify a URI's contents before it is written to disk.  Overriden
    # in this class to process the contents of a CSS file before it's written
    # to disk.
    #
    # @param  [String]    contentType  HTTP content type, for example `text/css'
    # @param  [Buffer]    body         the contents to modify
    # @param  [Function]  cb           callback to handle (`err`, 'modifiedBody`)
    #
    modifyContent: (contentType, body, cb) ->
        new CSSParser(@opts, body).run cb

    # Returns true if the contents of a URL with the provided `contentType` needs
    # to be modified before being written to disk.
    #
    # @param  [String]    contentType  HTTP content type, for example `text/css'
    # @return [Boolean]  returns true of the provided `contentType` needs to be modified
    #
    # @note Default behavior is to return `false`.
    #
    needsContentModification: (contentType) ->
        contentType.indexOf('css') != -1

    # Parse a single jQuery element.  Retrieves the URL from the element, saves it,
    # then replaces the URL in `tag` with the Moustache declaration for the registryKey.
    #
    # @param         [Object]    args       object containing runtime parameters
    # @option  opts  [Object]    element    DOM element (not jQuery!) for the object to parse
    # @option  opts  [String]    attribute  the attribute name in `tag` that contains the URL
    # @param         [Function]  cb         callback to handle (`err`)
    #
    parseOneUrl: (args, cb) =>
        u = args.element.getAttribute args.attribute
        return cb null unless u?.length > 0 and u not in _.values @registry
        registryKey = @nextRegistryKey

        if @isCdn u
#             console.log "HTMLParser.parseOneUrl, CDN  #{u}"
            @registry[registryKey] = u.replace RegExp('https*://'), '//'
            args.element.setAttribute args.attribute, @wrapRegistryKey(registryKey)
            return cb null

        @saveUrl u, (err, filename) =>
            console.log "HTMLParser.parseOneUrl, Error reading #{u}", err if err?
            return cb null unless filename?
#             console.log "HTMLParser.parseOneUrl, disk #{filename}"
            args.element.setAttribute args.attribute, @wrapRegistryKey(registryKey)
            @registry[registryKey] = filename
            cb null

    # Parse URLs for `tag` using `attribute`.  URLs are tested to see if they really
    # need to be read.  (URLs for CDN sites are left alone...).  If the URL needs
    # to be read, then that happens last.
    #
    # @param  [Object]    window     window object to search for `tags`
    # @param  [String]    tag        HTML tag name to search for (`link`, `script`, etc.)
    # @param  [String]    attribute  Atribute name in the tag that holds the URL (`href`, `src`, etc.)
    # @param  [Function]  cb         callback to handle (`err`)
    #
    parseUrls: (window, tag, attribute, cb) ->
        # Note of interest:  window.$(tag) returns a list of elements.
        # Downstream needs to use standard DOM accessors to retrieve and set
        # the attribute named by  `attribute`.
        #
        options = (element: e, attribute: attribute for e in window.$(tag))
        async.eachSeries options, @parseOneUrl, cb

    # Process the URL in `opts`.  Processing includes
    # * Reading the URL content
    # * Reading all CSS, script and image files from the site
    # * Parsing for files to read and storing them on the disk
    # * Using `mustache` to update the URL content to use filenames
    # * Saving the URL content to disk
    #
    # @param         [Function]  cb   callback to handle (`err`, `workingTemplate`)
    # @note This method returns a working template to maintain consistency through the Base.
    # @see Base.modifyContent
    #
    run: (cb) ->
        window = null
        tasks = []
        tasks.push (cb)    => @localRequest @opts.url, cb
        tasks.push (resp, body, cb) ->
            return cb err, null if err?
            return cb "HTMLParser.run, failed to read #{@opts.url}, response is #{resp.statusCode}" unless resp.statusCode == 200
            jsdom.env body, config.JQUERY, cb
        tasks.push (w, cb) -> window = w; cb null
        tasks.push (cb)    => @parseUrls window, 'link', 'href', cb
        tasks.push (cb)    => @parseUrls window, 'script', 'src', cb
        tasks.push (cb)    => @parseUrls window, 'img', 'src', cb
        # TODO: separate classes to allow common functions for HTML , CSS and <style>
        # TODO: <meta content="http..."
        # TODO: <style>.  Plug in whole <style> contents after parsing for URLs and replacing them with filenames.
        tasks.push (cb)    => @finalize window, cb
        async.waterfall tasks, cb

module.exports =
    HTMLParser: HTMLParser
