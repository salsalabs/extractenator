_         = require 'underscore'
async     = require 'async'
config    = require './config'
css       = require 'css'
mustache  = require 'mustache'
{Base}    = require './base'

# Class to parse a CSS buffer and modify any declarations that contain `url()`.
# The declarations containing `url()` are generally ones that need an external
# file to be rendered.  For example, images for `background` declarations and 
# fonts for font-family declarations.  This class extracts the referenced URLs,
# saves them to disk and modifies the CSS buffer to use the filename instead
# of the URL.
#
# When this class has completed the `body` property will contain the modified
# CSS body.
#
class CSSParser extends Base
    # Constructor.  Instantiates this class.  The arg `body` contains the
    # CSS contents that need to be modified and returned.  Modification in
    # this context means to find any referenced files, save them, then add
    # the saved filenames to key registry.
    #
    # @param         [Object]    opts  runtime parameters
    # @option  opts  [String]    url   URL to read
    # @option  opts  [String]    dir   directory to use for storing files
    # @option        [Buffer]    body  text to parse and return
    #
    constructor: (opts, @body) ->
        super opts
        console.log "CSSParser constructor, opts.url is #{opts.url}, opts.dir is #{opts.dir}"

    # Fix a declaration.  The provided declaration, `decl` must contain a `url()`
    # part.  The `url()` part is decided to retrieve the URL of a resource.  THe
    # URL is saved to disk, creating a filename.  The filename is used to replace
    # the URL in the `url()` part of the declaration, and the declaration
    # is returned.
    #
    # @param         [Object]    decl      declaration typically containing
    # @option  decl  [String]    type      'declaration'
    # @option  decl  [String]    property  a CSS property like 'background-image'
    # @option  decl  [String]    value     a string containing `url(resource URL)`
    # @option  decl  [Object]    position  a position object
    # @param         [Function]  cb        callback to handle (`err`, 'decl')
    #
    fixDeclaration: (decl, cb) =>
        # console.log "CSSParser.fixDeclaration: decl is", decl
        u = /url\(['"]*(.+?)['"]*\)/.exec(decl.value)[1]
        console.log "CSSParser.fixDeclaration: URL is #{u}"

        if @isCdn u
            # @debug "CSSParser.fixDeclaration, CDN  #{u}"
            decl.value = u.replace RegExp('https*://'), '//'
            @debug "CSSParser.fixDeclaration, decl AFTER is", decl
            return cb null

        # Don't save resources with built-in data.
        return cb null if /^data:/.test u

        console.log "CSSParser.fixDeclaration: saving #{u}"
        @saveUrl u, (err, filename) =>
            @debug "CSSParser.fixDeclaration, err is #{err}, filename is #{filename}"
            @debug "CSSParser.fixDeclaration, Error reading #{u}", err if err?
            return cb null, decl unless filename?
            console.log "CSSParser.fixDeclaration, filename #{filename}"
            registryKey = @nextRegistryKey
            decl.value = "url(\"#{@wrapRegistryKey(registryKey)}\")"
            @debug "CSSParser.fixDeclaration, fixed decl is #{JSON.stringify decl}"
            Base.registry[registryKey] = filename
            console.log "CSSParser.processElement: registry[#{registryKey}] is #{Base.registry[registryKey]}"
            cb null

    # Returns true if the contents of a URL with the provided `contentType` needs
    # to be modified before being written to disk.
    #
    # @param  [String]   contentType  HTTP content type, for example `text/css'
    # @return [Boolean]  returns true of the provided `contentType` needs to be modified
    #
    # @note This class overrides this method to return `true`.
    #
    needsContentModification: (contentType) -> 
        contentType.indexOf('css') != -1

    # Process the body.  Processing includes
    #
    # * Searching for `url()` declarations
    # * Extracting the URL from each `url()` declaration
    # * Saving the URL to disk
    # * Replacing the URL in the `url()` declaration with the content filename
    #
    # @param         [Function]  cb   callback to handle (`err`)
    #
    run: (cb) ->
        obj = css.parse @body.toString(), silent: true
        tasks = []
        tasks.push (cb) =>
            decls = []
            for rule in obj.stylesheet.rules when rule.declarations?
                try
                    d = rule.declarations.filter (x) -> RegExp('url\\(').test x.value
                    decls = _.union decls, d if d.length > 0
                catch err
                     @debug "Warning: #{err}"
            async.eachSeries decls, @fixDeclaration, cb
        tasks.push (cb) =>
            @body = css.stringify obj
            template = mustache.render @body, Base.registry
            cb null, template
        async.waterfall tasks, cb

module.exports =
    CSSParser: CSSParser
