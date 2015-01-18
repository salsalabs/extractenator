_            = require 'underscore'
async        = require 'async'
fs           = require 'fs'
jsdom        = require 'jsdom'
mustache     = require 'mustache'
opts         = require 'commander'
path         = require 'path'
request      = require 'request'
url          = require 'url'
wrench       = require 'wrench'

CDN_HOSTS    = [ 'ajax.googleapis.com']
JQUERY       = ["//ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js"]
serialNumber = 0
registry     = {}
USER_AGENT   = ['Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36',
               ' (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36'].join ''

# Get the next registry key.  The registry key uses the `serialNumber` session
# value.
#
# @returns  [String]  the next registry key
#
getRegistryKey = () -> "f#{serialNumber++}"

# Returns true if the provide `uri` is for a known CDN host. This includes any
# `uri` that starts with '//' or whose hostname is in the known CDN host list.
#
# @param    [String]  uri  URI to test
# @return   [Boolean]  returns true if the uri is for a known CDN host
#
isCdn = (u) ->
    return true if RegExp('^//').test u
    r = url.parse u
    return r.hostname in CDN_HOSTS

# Parse a single jQuery element.  Retrieves the URL from the element, saves it,
# then replaces the URL in `tag` with the Moustache declaration for the registryKey.
#
# @param         [Object]    opts       object containing runtime parameters
# @option  opts  [Object]    element    DOM element (not jQuery!) for the object to parse
# @option  opts  [String]    attribute  the attribute name in `tag` that contains the URL
# @param         [Function]  cb         callback to handle (`err`)
#
parseOneUrl = (opts, cb) ->
    u = opts.element.getAttribute opts.attribute
    return cb null unless u?.length > 0 and u not in _.values registry
    registryKey = getRegistryKey()
    # Return now if the URL is a known CDN.
    #
    if isCdn u
        console.log "parseOneUrl, CDN  #{u}"
        registry[registryKey] = u.replace RegExp('https*://'), '//'
        opts.element.setAttribute opts.attribute, "{{{#{registryKey}}}}"
        return cb null
    # Everything else is a file that needs to be saved.
    #
    saveUrl u, (err, filename) =>
        console.log "parseOneUrl, Error reading #{u}", err if err?
        return cb null unless filename?
        console.log "parseOneUrl,  disk #{u}"
        opts.element.setAttribute opts.attribute, "{{{#{registryKey}}}}"
        registry[registryKey] = filename
        cb null

# Parse URLs for `tag` using `attribute`.  URLs are tested to see if they really
# need to be read.  (URLs for CDN sites are left alone...).  If the URL needs
# to be read, then that happens last.
#
# @param  [Object]    window     window object to search for `tags`
# @param  [String]    tag        HTML tag name to search for (`link`, `script`, etc.)
# @param  [String]    attribute  Atribute name in the tag that holds the URL
# @param  [Function]  cb         callback to handle (`err`)
#
#
parseUrls = (window, tag, attribute, cb) ->
    # Note of interest:  window.$(tag) returns a list of elements.
    # Downstream needs to use standard DOM accessors to retrieve and set
    # the attribute named by  `attribute`.
    #
    options = (element: e, attribute: attribute for e in window.$(tag))
    async.eachSeries options, parseOneUrl, cb

# Process the URL in `opts`.  Processing includes
#
# * Reading the URL content
# * Reading all CSS, script and image files from the site
# * Parsing for files to read and storing them on the disk
# * Using `mustache` to update the URL content to use filenames
# * Saving the URL content to disk
#
# @param         [Object]    opts  runtime parameters
# @option  opts  [String]    url  URL to read
# @option  opts  [String]    dir  directory to use for storing files
# @param         [Function]  cb   callback to handle (`err`)
#
run = (opts, cb) ->
    jsdom.env opts.url, JQUERY, (err, window) ->
        return cb err if err?

        tasks = []
        tasks.push (cb) -> parseUrls window, 'link', 'href', cb
        tasks.push (cb) -> parseUrls window, 'script', 'src', cb
        tasks.push (cb) -> parseUrls window, 'img', 'src', cb
        # TODO: separate classes to allow common functions for HTML , CSS and <style>
        # TODO: <meta content="http..."
        # TODO: <style>.  Plug in whole <style> contents after parsing for URLs and replacing them with filenames.
        async.waterfall tasks, (err) ->
            return cb err if err?

            template = jsdom.serializeDocument(window.document)
            writeFile 'registry.json', JSON.stringify(registry, null, '    ')
            writeFile 'template.html', template

            html = mustache.render template, registry
            writeFile 'modified.html', html
            cb null

# Write a URL to disk.  The file is stored in the provided directory using the
# content type returned from the read.
#
# @param  [String]    uri  URL (possibly relative) to write
# @param  [Function]  cb   callback to  handle (`err`, `outputPath`)
#
# @note This is an improvement over the Salsa extractor.  We provide a referer
# and manage cookies for all requests for files.
#
saveUrl = (uri, cb) ->
    return cb null, null unless uri?
    return cb null, null unless path.basename(uri)?.length > 0
    unless RegExp('^http').test uri
        r = url.parse opts.url
        r.pathname = uri
        uri = url.format r
    # jar option requires package 'tough-coookie'
    options =
        url: uri
        jar: true
        options:
            encoding: 'utf8'
        headers:
            'Referer': opts.url
            'User-Agent': USER_AGENT
    request options, (err, resp, body) ->
        return cb err, null if err?
        return cb resp.statusCode, options.url unless resp.statusCode == 200
        contentType = resp.headers['content-type'].split(';')[0]
        return cb null, uri unless validContentType contentType
        filename = path.join contentType, path.basename(uri)
        filename = filename.split('?')[0]
        writeFile filename, body
        cb null, filename

# Returns true if `contentType` is one of the content types that needs to
# be saved.  This keeps us from saving HTML and other junk.
#
# @param   [String]  contentType  the content type to test
# @return  [Boolean] returns true if the content type is one that needs to be saved
#
validContentType = (contentType) ->
    contentType = contentType.split(';')[0]
    parts = contentType.split('/')
    return true if parts[0] in ['image', 'video']
    return false if parts[0] not in ['application', 'text']
    return parts[1] not in ['html']

# Write a file to the output directory.  This method accepts a filename, goes
# a recursive directory creation and saves the content to disk.
#
# @param  [String]         filename  filename where `content` ends up
# @param  [String, Buffer] content  content to write to `filename`
# @throws [Error]  Errors are thrown by underlying call, `fs.writeFileSync`
#
writeFile = (filename, content) ->
    filename = path.join(opts.dir, filename)
    wrench.mkdirSyncRecursive path.dirname filename
    fs.writeFileSync filename, content

# Demonstrates that we can do the following:
#
# * modify an element attribute and have the change be permanent in the DOM
# * Save the modified contents to disk.
#
opts
    .description('Read a URL with JSDOM and see if mods can be stored to disk.')
    .option('--url <text>', 'URL to read')
    .option('--dir <text>', 'directory to put content')
    .parse(process.argv);
throw new Error "All arguments are required!" unless opts.url?.length > 0 and opts.dir?.length > 0
run opts, (err, whatever) ->
    throw err if err?
    process.exit 0
