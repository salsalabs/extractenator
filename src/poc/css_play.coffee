_            = require 'underscore'
css          = require 'css'
fs           = require 'fs'
opts         = require 'commander'
path         = require 'path'

opts
    .description('Play with modifying a CSS file.')
    .option('--file <text>', 'file to read')
    .option('--dir <text>', 'directory to put content')
    .parse(process.argv);
throw new Error "All arguments are required!" unless opts.file?.length > 0 and opts.dir?.length > 0

contents = fs.readFileSync opts.file, encoding: 'utf8'
obj = css.parse contents, silent: true, source: opts.file
decls = []
for rule in obj.stylesheet.rules when rule.declarations?
    decls = _.union decls, rule.declarations.filter (x) -> RegExp('url\\(').test x.value
for d in decls
    u = /url\((['"]*(.+)['"]*)\)/.exec(d.value)[1]
    d.value = d.value.replace /url\(.+\)/, u.toUpperCase()
fs.writeFileSync path.basename(opts.file), css.stringify obj
# This is what we're looking for...
#
# { type: 'rule',
#   selectors: [ '.read-more a' ],
#   declarations: 
#    [ { type: 'declaration',
#        property: 'background-image',
#        value: 'url(http://library.lwv.org/sites/all/themes/lwv/images/more-arrow.png)',
#        position: [Object] },

# (console.log r for r in obj.stylesheet.rules)


# CSS Process will be
#
# 1. read css file
# 2. parse, ignoring errors
# 3. Search for values having 'url('
# 4. use saveUrl to save the url.  That returns a filename.  put the filename into  the value.
# 5. continue for all qualifying values
# 6. (Minify?)
# 7. Save the serialized version to disk
#
