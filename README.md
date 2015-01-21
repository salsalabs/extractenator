# Better Template Extractor for Salsalabs

Extractenator is a program that accepts a URL from your website and creates a 
Salsa template.  Salsa templates can be thought of as picture frames that surround
each Salsa page.  Templates provide the look-and-feel of your website so that 
your Salsa pages look the same as your website.

# Table of Contents

## <a href="#background">Background</a>
## <a href="#legalities">Legalities</a>
## <a href="#summary">Summary</a>
## <a href="#installation">Installation</a>
## <a href="#make_it_go">Make it go!</a>

<a name="background"></a>
## Background

### Templates must be "secure"

Salsa's templates are used for donation pages, and must be secure.  "Secure" in
this case means that there is a locked padlock in the browser when a supporter or
donor goes to any of your Salsa pages.

Technically a "secure" template (and the pages that use it) are served up by 
Salsa using the secure HTTPS protocol.  Browsers know that a page is secure, and
will block any content that comes from a site with `http://` in the URL.

### Copying resources to Salsa

Since getting HTTPS set up on a website can be complex and prohibitively expensive,
Salsa provides a way to host the files and resources uses by your template.  The
end result is that both the template and all of the resources that it uses are
served up to browsers using HTTPS.  Doing this saves money for our customers and
makes sure that pages like donation pages are secure when they are used.

Copying resources form your website to Salsa is the most important thing that
the Extractenator does.  Quite frankly, it's trivially easy to copy a website from 
one place to another.  The challenge is getting all of the files and making sure
that all of the interdependencies are resolved.

For example, Cascading Style Sheet (CSS) files have a `url` declaration.  This
declaration is used to specify the exact location of a particular resource.  If
the `url` declaration is not changed, then the resource will still be retrieved
from your website after the template is extracted.  That resource will more than
likely not be secure.  The browser will block it and your donor won't have the
locked padlock that they want to see.Better Template Extractor for Salsalabs

# Why "better template extractor?"

At this writing, the Salsa template extractor is an ancient thing thing does not 
always extract pages correctly.  This causes both Salsa and its clients tons of 
aggravation, irritation and additional cost, and I, for one, got fed up with that.

Extractenator duplcates the existing extractor's capabilities. The template and
all of the files referenced by the template are downloaded to Salsa.  The template
is modified to correctly reference the downloaded files.

In addition, Extractenator successfully extracts files that Salsa's extractor
simply cannot handle.  Extractenator does the right thing with URLs requested from
websites, thus avoiding the `403` errors that plagues clients using the Salsa
extractor.

Extractentator also searches
all resource files for other resources and makes sure that those are retrieved as well.
Gone are the days when a client or specialist had to edit a CSS file to make a font
or background image appear.

This is definite upside for Salsa's clients.  Salsa's clients are outstanding at
their jobs, but generally are not familiar with the internals of CSS.  Extractenator
acknowledges that and does the right thing so that thehy don't have to be CSS gurus
to use Salsa.

The resulting templates are both clean and secure.  Resource
files required by the templates are stored in the same way that Salsa stores the
files retrieved during a "template download".  Neither the client nor experienced
Salsa support specialists will be able to tell the difference between a template 
extracted by the Salsa extractor and one extracted by Extractenator.  (Okay, except
the one created by Extractenator works correctly the first time it's used.)

My hope is that this free-and-open version template extractor will reduce headaches
and cost for all of us and leave us a bit more time for drinking really good coffee!

<a name="legalities"></a>
# Legalities (really short)

Licensing terms and conditions may be found in the file `LICENSING` in the same
directory as this file. **Do not** contact Salsalabs Support about this package.
You will be sorely disappointed and they will be pissed off.

<a name="got_a_problem"></a>
# Got a problem?
[Click here] (https://github.com/salsalabs/extractenator/issues "Click here
to report any problems with the Extractenator") to report problems,
make suggestions, offer funding or pass along a good joke.  Griping, whining
and error reports that don't provide concrete examples may be deleted without
being read.  Just sayin'...

<a name="summary"></a>
# Summary

This package contains a program that

* Accepts a URL to be extracted
* Reads the URL and stores it locally
* Reads all of the resources used by the page (images, scripts, CSS, etc.) and
stores them locally
* Scans the resources and copies any resources embedded in each
* Modifies any resource files to use the correct URLs for downloaded resources
* Copies the resources to Salsa
* Modifies the template to replace resource URLs from your website with URLs
from Salsa
* Stores the template on Salsa
* Cleans up after itself

## Still to do...

This package will support a facility so that you can choose where Salsa content
will go. Until that facility is working, the template saved to Salsa will need
to be edited manually so that the Salsa "template tags" are where you want
Salsa content to appear.

<a name="installation"></a>
# Installation

## Prerequisites
Before installation, you should have these software packages installed:

1. [Node.js](http://nodejs.org/ "Node.js's Homepage")
2. [CoffeeScript](http://coffeescript.org/ "Coffeescript's Homepage")
3. [Git](http://git-scm.com/ "Homepage for the Git source control program")

## Getting Extractentator
* Clone the [Extractenator repository](https://github.com/salsalabs/extractenator)
```bash
cd YOUR_WORKSPACE_DIRECTORY
git clone https://github.com/salsalabs/extractenator.git
```
* Retrieve the resources needed by Extractenator.
```bash
cd extractenator
npm update
npm run prebuild
```
Ignore any warnings.  If there are errors then [please report them here.]
(https://github.com/salsalabs/extractenator/issues
"Click here to report any problems with the Extractenator")
* That's it!  Extractenator is ready to use!

<a name="make_it_go"></a>
# Make it go!

The extraction part of Extractenator is started from the command line.  Use 
`--help` to see a list of options.
```bash
cd YOUR_WORKSPACE_DIRECTORY/extractenator
node lib/app --help
```
Which should return something like this:
```
  Usage: app.coffee [options]

  Read a URL and extract a Salsa template from it.

  Options:

    -h, --help    output usage information
    --url <text>  URL to read
    --dir <text>  directory where the temlate and all resource files are stored.
```
All arguments are requiored.  Failure to provide one or more arguemnts gets
this treatment:
```
Error: All arguments are required!
  at Object.<anonymous> (/home/ubuntu/workspace/src/app.coffee:17:11)
  at Object.<anonymous> (/home/ubuntu/workspace/src/app.coffee:2:1)
  at Module._compile (module.js:456:26)
```
Here's an example extraction:

```
cd workspace/extractenator
node lib/app --url http://helpthelittlechipmunks/about-us.html --directory HTLC
```
When this example completes, directory `HTLC` will have a structure like this:
```
HTLC
HTLC/registry.json
HTLC/template.html
HTLC/working_template.html
HTLC/application
HTLC/application/javascript
HTLC/application/javascript/jquery.cookie.js
HTLC/application/javascript/script.js
HTLC/application/javascript/plugins.js
HTLC/application/x-javascript
HTLC/application/x-javascript/buttons.js
HTLC/application/x-javascript/modernizr-1.7.min.js
HTLC/image
HTLC/image/jpeg
HTLC/image/jpeg/Protests.jpg
HTLC/image/jpeg/slider.jpg
HTLC/image/jpeg/web.jpg
HTLC/image/jpeg/cruiseship.jpg
HTLC/image/jpeg/Slider.jpg
HTLC/image/vnd.microsoft.icon
HTLC/image/vnd.microsoft.icon/favicon.ico
HTLC/image/gif
HTLC/image/gif/icon_alert_new.gif
HTLC/image/png
HTLC/image/png/icons-social.png
HTLC/image/png/logo.png
HTLC/image/png/none.png
HTLC/image/png/sort_paginate.png
HTLC/image/png/chipmunk1.png
HTLC/image/png/down.png
HTLC/image/png/icons-8.png
HTLC/image/png/logo-print.png
HTLC/image/png/up.png
HTLC/image/png/logo-mobile.png
HTLC/image/png/logo-tv.png
HTLC/image/png/ungraded.png
HTLC/text
HTLC/text/javascript
HTLC/text/javascript/chippy.js
HTLC/text/javascript/jsapi
HTLC/text/css
HTLC/text/css/1.css
```
The file `template.html` will be the template to send to Salsa.  All of the resource
URLs have been resolved to Salsa URLs and the template has been modified.
