require! \css
require! \request
require! \async
{each, filter, flatten, map, take-while} = require 'prelude-ls'

has-declarations = (x) -> x.declarations?
has-url = (x) -> /url/.test x.value
see-value = (x) -> console.log x.value
fix-url = (x) -> x.value = x.value.replace 'url', 'URL'
u = "https://s.4cdn.org/css/yotsubanew.653.css"
tasks = 
  * (cb) -> request u, encoding: 'utf8', cb
  * (resp, body, cb) ->
      console.log "read #u"
      console.log "status code #{resp.statusCode}"
      console.log "content type #{resp.headers['content-type']}"
      console.log "content length #{resp.headers['Content-Length']}"
      console.log "body is a #{typeof body}"
      console.log "body length #{body.length}"

      obj = css.parse body, silent: true, source: u
      console.log "CSS object has a stylesheet? #{obj.stylesheet?}"
      return cb null unless obj.stylesheet?
      console.log "CSS object stylesheet has rules? #{obj.stylesheet.rules?}"
      retrun cb null unless obj.stylesheet.rules?
      console.log "CSS object has #{obj.stylesheet.rules.length} rules"
      # useful-rules = take-while (.declarations?.length > 0), obj.stylesheet.rules
      # console.log "CSS rules contain #{useful-rules.length} useful rules"
      # url-declarations = map (.declarations), useful-rules 
      # console.log "CSS rules contain #{url-declarations.length} declarations"
      # all-declarations-inner = flatten url-declarations
      # console.log "CSS rules contain #{all-declarations-inner.length} inner declarations"
      # url-all-declarations = filter has-url, all-declarations-inner
      # console.log "CSS rules contain #{url-all-declarations.length} inner declarations with URLs"
      take-while (.declarations?.length > 0), obj.stylesheet.rules
        |> map (.declarations)
        |> flatten
        |> filter has-url
        |> each fix-url
      console.log "Fixables ", fixables
 #     { type: 'rule',
  #       selectors: [ '#boardNavDesktop .pageJump a' ],
  #       declarations: 
  #         [ { type: 'declaration',
  #             property: 'padding-right',
  #             value: '5px',
  #             position: [Object] } ],
  #       position: 
  #         Position {
  #           start: { line: 1, column: 5143 },
  #           end: { line: 1, column: 5191 },
  #           source: 'https://s.4cdn.org/css/yotsubanew.653.css' } }
      cb null

async.waterfall tasks, (err, whatever) ->
  console.log "waterfall error is ", err 
  console.log "waterfall whatever is ", whatever
  process.exit 0
