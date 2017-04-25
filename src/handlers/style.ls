require! {
    './css': { CSSHandler }
}
# Override base class to store CSS back in the element (not in a file)
export class StyleHandler extends CSSHandler
    fetch: (cb) -> cb null, @elem .html!
    save: (buffer, cb) -> @elem .html buffer ; cb null
    store-filename: ->
