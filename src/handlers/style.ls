require! {
    './css': { CSSHandler }
}
# Override base class to store CSS back in the element (not in a file)
export class StyleHandler extends CSSHandler
    fetch: (cb) ->
        console.log "StyleHandler.fetch: @uri is #{@uri or \null}, @resolved is #{@get-resolved!}"
        console.log "StyleHandler.fetch: buffer is #{@elem.html! .length} bytes"
        console.log @elem.html!
        cb null, @elem.html!
    get-resolved: -> return \buffer
    save: (buffer, cb) -> @elem.html buffer ; cb null
    store-filename: ->
