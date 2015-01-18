_         = require 'underscore'
async     = require 'async'
config    = require './config'
css       = require 'css'
mustache  = require 'mustache'
{Base}    = require './base'

# Class to parse a CSS buffer and modify any declarations that contain `url()`.
# The declarations containing `url()` are generally ones that need an external
# file to be rendered.  For example images for `background` declarations and 
# fonts for font-family declarations.  This class extracts the referenced URLs,
# saves them to disk and modifies the CSS buffer to use the filename instead
# of the URL.
#
# When this class has completed the `body` property will contain the modified
# CSS body.
#
class CSSParser extends Base
    # Constructor.  Instantiates this class using the provided runtime
    # parameters and a CSS buffer to modify.
    # @param         [Object]  opts  object containing runtime parameters
    # @option  opts  [Object]  url   the url to parse
    # @option  opts  [String]  dir   directory for storing files
    # @option        [String]  body  CSS text to edit and modify
    #
    constructor: (@opts, body) ->
        super @opts
        @body = body

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
    # @param         [Function]  cb        callback to handle (`'err`, 'decl')
    #
    fixDeclaration: (decl, cb) =>
        u = /url\((['"]*(.+)['"]*)\)/.exec(decl.value)[1]
#         console.log "CSSParser.fixDeclaration, u is #{u}"
        registryKey = @nextRegistryKey

        if @isCdn u
#             console.log "CSSParser.fixDeclaration, CDN  #{u}"
            @registry[registryKey] = u.replace RegExp('https*://'), '//'
            decl.value = "url(\"#{@wrapRegistryKey(registryKey)}\")"
            console.log "CSSParser.fixDeclaration, decl AFTER is", decl
            return cb null

        @saveUrl u, (err, filename) =>
#             console.log "CSSParser.fixDeclaration, Error reading #{u}", err if err?
            return cb null, decl unless filename?
#             console.log "CSSParser.fixDeclaration, disk #{file}"
            @registry[registryKey] = filename
            decl.value = "url(\"#{@wrapRegistryKey(registryKey)}\")"
            cb null

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
                d = rule.declarations.filter (x) -> RegExp('url\\(').test x.value
                decls = _.union decls, d
            async.eachSeries decls, @fixDeclaration, cb
        tasks.push (cb) =>
            @body  = css.stringify obj
            template = mustache.render @body, @registry
            cb null, template
        async.waterfall tasks, cb

module.exports =
    CSSParser: CSSParser
