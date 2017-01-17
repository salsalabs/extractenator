require! path

# Class to represent an organization for the Extractinator 900 (tm).
# chapter_KEY and filename are optional and should be null when unused.
export class Org
    name: \CycleTO
    # Choose an input.  Filename is generally document.innerHTML.
    uri: 'https://www.cycleto.ca/'
    filename: null
    organization-key: 51666
    # Optional chapter-key.  Leave null otherwise.
    chapter-key: null
    template-key: 21103
    tag-selector: '#block-system-main'
    dir: null

    # Constructor.  Build the output directory.
    ->
        @dir = switch @chapter-key
        | null => "/o/#{@organization-key}/images/#{@template-key}"
        | _    => "/o/#{@organization-key}/c/#{@chapter-key}/images/#{@template-key}"
