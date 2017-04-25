require! {
    './handlers/html': { HTMLHander }
}

# Override the base class to retrieve HTML from an org and process it fully.
class Extractenator9000 extends HTMLHandler
    ->
        super @org.uri, null, null
        @content-type = ''

    # Override to use the URI from the org record as the resolved URL.
    get-resolved: -> @org.uri

    # Override to use the URI in the Org record.
    get-uri: -> @org.uri
    
    # Override to not store the filename in a structure.
    store-filename: ->
