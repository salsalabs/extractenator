require! path

# Class to represent an organization for the Extractinator 900 (tm).
# chapter_KEY and filename are optional and should be null when unused.
export class Org
    name: "UUDAN"
    # Choose an input.  Filename is generally document.innerHTML.
    uri: "http://www.uudeladvo.org/wp/sample-page/"
    filename: null
    organization-key: 51510
    # Optional chapter-key.  Leave null otherwise.
    chapter-key: 454
    template-key: 21080
    tag-selector: '#post-2'
    dir: null

    # Constructor.  Build the output directory.
    ->
        @dir = switch @chapter-key
        | null =>      "/o/#{@organization-key}/images/#{@template-key}"
        | otherwise => "/o/#{@organization-key}/c/#{@chapter-key}/images/#{@template-key}"
    