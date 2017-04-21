require! {
    css
    'prelude-ls' : { map, each, filter }
    request
    cheerio
}

data = """
@import url("http://www.cesr.org/sites/all/modules/calendar/css/calendar_multiday.css?oo0bhk");
@import url("http://www.cesr.org/sites/all/modules/date/date_api/date.css?oo0bhk");
@import url("http://www.cesr.org/modules/field/theme/field.css?oo0bhk");
@import url("http://www.cesr.org/sites/all/modules/mollom/mollom.css?oo0bhk");
@import url("http://www.cesr.org/modules/node/node.css?oo0bhk");
@import url("http://www.cesr.org/sites/all/modules/views/css/views.css?oo0bhk");
@import url("http://www.cesr.org/sites/all/modules/media/modules/media_wysiwyg/css/media_wysiwyg.base.css?oo0bhk");
"""

u = 'http://www.cesr.org'
obj = css.parse data.toString!, silent: true, source: u
obj.stylesheet.rules |> each (it) -> console.log it
obj.stylesheet.rules |> map (.import) |> filter (it) -> /url/.test it.import |> each (it) -> console.log it

(err, resp, body) <~ request u
through err if err?
$ = cheerio.load body.to-string!, 'utf-8'
$ 'style[src!=""]' .each -> console.log $(this).html()
