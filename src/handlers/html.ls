require! {
    async
    cheerio
    './anchor': { AnchorHandler }
    '../config'
    './css': { CSSHandler }
    './file': { FileHandler }
    './style': { StyleHandler }
}

# Override base class to parse HTML, store the template tags and process
# read, transform and store the DOM.
export class HTMLHandler extends FileHandler
    # Override to process an HTML file.  Elements that may contain URLs to site
    # files are read and processed.  Things like images and scripts are read 
    # and stored.  CSS is parsed for URLs.  Those are read and stored.
    transform: (body, cb) ->
        $ = cheerio.load body.to-string!, 'utf-8'
        e = $ @org.tag-selector
        switch e.length
        | 0 => return cb "tag selector '#{@org.tag-selector}' does not indentify a node"
        | 1 =>
        | otherwise => return cb console.log "tag selector '#{@org.tag-selector}' identifies #{e.length} nodes, must only identify one."
        e.empty! .append config.TEMPLATE_TAGS

        u = @org.uri
        task-list = []
        $ 'a'                    .each -> task-list.push new AnchorHandler u, $(this), 'href'
        $ 'img:not([src^=data])' .each -> task-list.push new FileHandler   u, $(this), 'src'
        $ 'link[rel*=icon]'      .each -> task-list.push new FileHandler   u, $(this), 'href'
        $ 'script[src]'          .each -> task-list.push new FileHandler   u, $(this), 'src'
#        $ 'link[rel=stylesheet]' .each -> task-list.push new CSSHandler    u, $(this), 'href'
        $ 'style'                .each -> task-list.push new StyleHandler u, $(this), null
 
        (err) <- async.each task-list, (t, cb) -> t.run cb
        console.log "run: process-task-list returned err", err if err?
        return cb err, body if err?
        cb null, $.html!
