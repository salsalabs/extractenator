#!/usr/bin/env coffee
opts = require 'commander'
{HTMLParser} = require './html_parser'

# Program to gather runtime parameters for extracting a template.  After parameters
# are validated the HtmlParser runs to extract a COSM template from the specified
# URL.
#
opts
    .description('Read a URL with JSDOM and see if mods can be stored to disk.')
    .option('--url <text>', 'URL to read')
    .option('--dir <text>', 'directory to put content')
    .parse(process.argv);
throw new Error "All arguments are required!" unless opts.url?.length > 0 and opts.dir?.length > 0
new HTMLParser(opts).run (err, whatever) ->
    throw err if err?
    process.exit 0
