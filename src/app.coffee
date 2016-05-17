#!/usr/bin/env coffee
opts         = require 'commander'
{HTMLParser} = require './html_parser'

DESCRIPTION = '''Read a URL and extract a Salsa template from it.'''
DIR_DESC = '''directory where the template and all resource files are stored.'''

# Program to gather runtime parameters for extracting a template.  After parameters
# are validated the HtmlParser runs to extract a Salsa Classic template from the specified
# URL.
#
opts
    .description(DESCRIPTION)
    .option('--url <text>', 'URL to read')
    .option('--dir <text>', DIR_DESC)
    .option('--debug', 'show debug output')
    .option('--template-selector <text>', 'CSS/jQuery selector of the element that holds the template tags')
    .option('--auth-username <text>', 'username for reading from site')
    .option('--auth-password <text>', 'password for readin from site')
    .parse(process.argv);
console.log opts
throw new Error "--url and --dir are *both* required!" unless opts.url?.length > 0 and opts.dir?.length > 0
new HTMLParser(opts).run (err, whatever) ->
    throw JSON.stringify err if err?
    process.exit 0
