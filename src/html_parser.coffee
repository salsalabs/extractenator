_           = require 'underscore'
async       = require 'async'
config      = require './config'
jsdom       = require 'jsdom'
mustache    = require 'mustache'
url         = require 'url'
{Base}      = require './base'
{CSSParser} = require './css_parser'

# Class to extract a Salsalabs Salsa Classic template from the URL provided in
# the calling arguments.  A directory is used to cache the files needed by the
# extracted template.  When all files are retrieved and corrected then they
# are moved into a directory on Salsa.  The template itself is inserted into
# the Salsa Classic `template` database.
#
TEMPLATE_TAGS = """
<!-- Template tags placed by Extractenator 9000. -->
<!-- TemplateBeginEditable name="content" -->
<h1>Page content here.</h1>
<!-- TemplateEndEditable -->
"""
class HTMLParser extends Base
    # Typically, the last step is to use Mustache to convert the modified
    # contents of the website to a template using the local files.  Doing that
    # causes all of the file to be relative URLs, making it easy for Salsa Classic
    # to use them after they are uploaded.
    #
    # @param  [Object]    window    window object to save
    # @param  [Function]  cb        callback to handle (`err`)
    #
    finalize:  (window, cb) ->
        @writeFile 'registry.json', JSON.stringify(Base.registry, null, '    ')
        template = jsdom.serializeDocument window.document
        @writeFile 'working_template.html', template
        @writeFile 'template.html', mustache.render(template, Base.registry)
        cb null

    # Methond to clear out an element and replace the contents with Salsa's template tags.
    # @param  [Object]    window    window object to save
    # @param  [String]    selector  CSS/jQuery selector of the element to use
    # @param  [Function]  cb        callback to handle (`err`)
    insertTemplateTags: (window, selector, cb) ->
        @debug "insertTemplateTags: selector is #{selector}"
        return cb null unless selector?.length > 0
        e = window.$(selector)
        warning = "Selector '#{selector}' needs to match one element but matches #{e.length}."
        return cb warning unless e.length == 1
        e.empty().append(TEMPLATE_TAGS)
        @debug "insertTemplateTags: replaced contents of '#{selector}' with template tags."
        cb null

    # Method to modify a URI's contents before it is written to disk.  Overriden
    # in this class to process the contents of a CSS file before it's written
    # to disk.
    #
    # @param  [String]    uri          URI for `body`
    # @param  [String]    contentType  HTTP content type, for example `text/css'
    # @param  [Buffer]    body         the contents to modify
    # @param  [Function]  cb           callback to handle (`err`, 'modifiedBody`)
    #
    modifyContent: (uri, contentType, body, cb) ->
        @debug "HTMLParser.modifyContent contentType #{contentType} #{body.length}-char body, calling CSSParser? #{contentType.indexOf('css') != -1}"
        if contentType.indexOf('css') != -1
            opts = _.clone @opts
            opts.url = uri
            new CSSParser(opts, body).run cb
        else
            cb null, body

    # Returns true if the contents of a URL with the provided `contentType` needs
    # to be modified before being written to disk.
    #
    # @param  [String]   contentType  HTTP content type, for example `text/css'
    # @return [Boolean]  returns true of the provided `contentType` needs to be modified
    #
    # @note This class overrides this method to return `true`.
    #
    needsContentModification: (contentType) -> 
        @debug "HTMLParser.needsContentModification contentType #{contentType} returning #{contentType.indexOf('css') != -1}"
        contentType.indexOf('css') != -1

    # Resolve a single anchor `href`.  If the href is relative, then the href
    # attribute value is replaced by the full URL for the page.
    #
    # @param  [Object]  element  DOM anchor element (<a>) to modify
    #
    processAnchor: (e) ->
        href = e.getAttribute 'href'
        return unless href? and href.length > 0
        return if RegExp('^(http|mailto)').test href
        x = href
        href = url.resolve @opts.url, href
        @debug "HTMLParser.processAnchor: #{x} resolved to #{href}"
        e.setAttribute 'href', href

    # Resolve anchor `href` attributes.  This page will run on Salsa, and relative
    # URIs in `href` attributes need to be resolved against the site URL.  A click
    # on one of those links will then go to the site and not to Salsa.
    #
    # @param  [Object]    window     window object to search for `tag` elements
    # @param  [Function]  cb         callback to handle (`err`)
    #
    processAnchors: (window, cb) ->
        @processAnchor e for e in window.$('a')
        cb null

    # Parse a single jQuery element.  Retrieves the URL from the element, saves it,
    # then replaces the URL in `tag` with the Moustache declaration for the registryKey.
    #
    # @param         [Object]    args       object containing runtime parameters
    # @option  opts  [Object]    element    DOM element (not jQuery!) for the object to parse
    # @option  opts  [String]    attribute  the attribute name in `tag` that contains the URL
    # @param         [Function]  cb         callback to handle (`err`)
    #
    processElement: (args, cb) =>
        # Note: `args` is a list of DOM elements and not a list of jQuery elements.
        # If you modify this method, be sure to use standard DOM calls.
        #
        u = args.element.getAttribute args.attribute
        @debug "HTMLParser.processElement: attribute #{args.attribute} is #{u}"
        @debug "HTMLParser.processElement: #{u} in registry? #{u in _.values Base.registry}"
        return cb null unless u?.length > 0 and u not in _.values Base.registry
        registryKey = @nextRegistryKey
        @debug "HTMLParser.processElement: registry key is #{registryKey}"
        if @isCdn u
            @debug "HTMLParser.processElement: isCDN, #{u}"
            args.element.setAttribute args.attribute, u.replace RegExp('https*://'), '//'
            return cb null

        @debug "HTMLParser.processElement: saving #{u}"
        @saveUrl u, (err, filename) =>
            @debug "HTMLParser.processElement, Error reading #{u}", err if err?
            return cb null unless filename?
            @debug "HTMLParser.processElement, disk #{filename}"
            args.element.setAttribute args.attribute, @wrapRegistryKey(registryKey)
            Base.registry[registryKey] = filename
            @debug "HTMLParser.processElement: registry[#{registryKey}] is #{Base.registry[registryKey]}"
            cb null

    # Parse URLs for `tag` using `attribute`.  URLs are tested to see if they really
    # need to be read.  (URLs for CDN sites are left alone...).  If the URL needs
    # to be read, then that happens last.
    #
    # @param  [Object]    window     window object to search for `tag` elements
    # @param  [String]    tag        HTML tag name to search for (`link`, `script`, etc.)
    # @param  [String]    attribute  Atribute name in the tag that holds the URL (`href`, `src`, etc.)
    # @param  [Function]  cb         callback to handle (`err`)
    #
    processElements: (window, tag, attribute, cb) ->
        # Note of interest:  window.$(tag) returns a list of elements.
        # Downstream needs to use standard DOM accessors to retrieve and set
        # the attribute named by  `attribute`.
        #
        args = (element: e, attribute: attribute for e in window.$(tag))
        @debug "HTMLParser.processElements: processing #{args.length} #{tag} elements"
        async.eachSeries args, @processElement, cb

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
        tasks.push (resp, body, cb) =>
            return cb err, null if err?
            return cb "HTMLParser.run, failed to read #{@opts.url}, response is #{resp.statusCode}" unless resp.statusCode == 200
            jsdom.env body, config.JQUERY, cb
        tasks.push (w, cb) -> window = w; cb null
        tasks.push (cb)    => @insertTemplateTags window, @opts.templateSelector, cb
        tasks.push (cb)    => @processElements window, 'link', 'href', cb
        tasks.push (cb)    => @processElements window, 'script', 'src', cb
        tasks.push (cb)    => @processElements window, 'img', 'src', cb
        tasks.push (cb)    => @processAnchors window, cb
        # TODO: separate classes to allow common functions for <style> and <a> (for menus)
        # TODO: <meta content="http..."
        # TODO: <style>.  Plug in whole <style> contents after parsing for URLs and replacing them with filenames.
        # TODO: <a href="../whatever">Topic</a>
        tasks.push (cb)    => @finalize window, cb
        async.waterfall tasks, cb

module.exports =
    HTMLParser: HTMLParser
