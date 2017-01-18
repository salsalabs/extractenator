require! path

# Class to represent an organization for the Extractinator 900 (tm).
# chapter_KEY and filename are optional and should be null when unused.
export class Org
    name: \CleanAirCouncilPA
    # Choose an input.  Filename is generally document.innerHTML.
    uri: 'http://www.cleanairpa.org/'
    filename: null
    organization-key: 51176
    # Optional chapter-key.  Leave null otherwise.
    chapter-key: null
    template-key: 21112
    tag-selector: '.left-column'
    dir: null

    # Constructor.  Build the output directory.
    ->
        @dir = switch @chapter-key
        | null => "/o/#{@organization-key}/images/#{@template-key}"
        | _    => "/o/#{@organization-key}/c/#{@chapter-key}/images/#{@template-key}"
