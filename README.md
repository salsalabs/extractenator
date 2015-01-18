# Better Template Extractor for Salsalabs

Extractenator is a program that accepts a URL from your website and creates a 
Salsa template.  Salsa templates can be thought of as picture frames that surround
each Salsa page.  Templates provide the look-and-feel of your website so that 
your Salsa pages look the same as your website.

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

# Legalities (really short)

##Part I
    
    This software is placed into the public domain. The author(s) assume
    make no claims about suitability and claim no liabilty for anything.  Use
    at your own risk. Your mileage may vary.

##Part II
    This software package is **not** a product of SalsaLabs, and SalsaLab does not
    support it. **Do not** contact Salsalabs Support about this package.  [Do report
    any problems by clicking here.](https://github.com/salsalabs/extractenator/issues
    "Click here to report any problems with the Extractenator")

# Summary

This package contains a program that

* Accepts a URL to be extracted
* Reads the URL and stores it locally
* Reads all of the resources used by the page (images, scripts, CSS, etc.) and stores them locally
* Scans the resources and copies any resources embedded in each
* Modifies any resource files to use the correct URLs for downloaded resources
* Copies the resources to Salsa
* Modifies the template to replace resource URLs from your website with URLs from Salsa
* Stores the template on Salsa
* Cleans up after itself

##TODO

This package will support a facility so that you can choose where Salsa content will go.
Until that facility is working, the template saved to Salsa will need to be edited manually
so that the Salsa "template tags" are where you want Salsa content to appear.

## Dependencies

Before installation, you should have these software packages installed:

1. [Node.js](http://nodejs.org/ "Node.js's Homepage")
2. [CoffeeScript](http://coffeescript.org/ "Coffeescript's Homepage")
3. [Git](http://git-scm.com/ "Homepage for the Git source control program")

## Installation

* Clone the [Extractenator repository](https://github.com/salsalabs/extractenator)
```
cd YOUR_WORKSPACE_DIRECTORY
git clone https://github.com/salsalabs/extractenator.git
```
* Retrieve the resources needed by Extractenator.
```
cd extractenator
npm update
```
* That's it!  The extractenator is ready to use!

