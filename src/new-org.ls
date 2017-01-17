require! {
    path
    'prelude-ls': {each, keys}
    '../spec.json': spec
}

# Class to represent an organization for the Extractinator 900 (tm).
# chapter_KEY and filename are optional and should be null when unused.
export class Org
    name: null
    uri: null
    organization-key: null
    chapter-key: null
    template-key: null
    tag-selector: null
    dir: null

    # Constructor.  Build the output directory.
    ->
        console.log JSON.stringify spec
        @name = spec.name
        @uri = spec.uri
        @organization-key = spec.organization-key
        @chapter-key = spec.chapter-key
        @template-key = spec.template-key
        @tag-selector = spec.tag-selector
        @dir = switch @chapter-key
        | null => "/o/#{@organization-key}/images/#{@template-key}"
        | _    => "/o/#{@organization-key}/c/#{@chapter-key}/images/#{@template-key}"
        console.log 'name', @name
        console.log 'uri', @uri
        console.log 'organization-key', @organization-key
        console.log 'chapter-key', @chapter-key
        console.log 'template-key', @template-key
        console.log 'tag-selector', @tag-selector
        console.log 'dir', @dir
        process.exit 0
        console.log JSON.stringify @
