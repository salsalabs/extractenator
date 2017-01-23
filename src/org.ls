require! {
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
        @name = spec.\name
        @uri = spec.\uri
        @filename = spec.\filename
        @organization-key = spec.\organization-key
        @chapter-key = spec.\chapter-key
        @template-key = spec.\template-key
        @tag-selector = spec.\tag-selector

        @dir = switch @chapter-key
            | null => "/o/#{@organization-key}/images/#{@template-key}"
            | _    => "/o/#{@organization-key}/c/#{@chapter-key}/images/#{@template-key}"
