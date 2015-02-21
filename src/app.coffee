#!/usr/bin/env coffee
opts         = require 'commander'
{HTMLParser} = require './html_parser'

DESCRIPTION = '''Read a URL and extract a Salsa template from it.'''
DIR_DESC = '''directory where the temlate and all resource files are stored.'''

# Program to gather runtime parameters for extracting a template.  After parameters
# are validated the HtmlParser runs to extract a COSM template from the specified
# URL.
#
opts
    .description(DESCRIPTION)
    .option('--url <text>', 'URL to read')
    .option('--dir <text>', DIR_DESC)
    .option('--debug', 'show debug output')
    .parse(process.argv);
throw new Error "All arguments are required!" unless opts.url?.length > 0 and opts.dir?.length > 0
new HTMLParser(opts).run (err, whatever) ->
    throw err if err?
    process.exit 0
