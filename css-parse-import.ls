require! {
    css
    'prelude-ls' : { each, filter, flatten, map }
    request
    cheerio
}
u = 'http://www.cesr.org'

show-imports = ->
    data = """
    @import url("http://www.cesr.org/sites/all/modules/calendar/css/calendar_multiday.css?oo0bhk");
    @import url("http://www.cesr.org/sites/all/modules/date/date_api/date.css?oo0bhk");
    @import url("http://www.cesr.org/modules/field/theme/field.css?oo0bhk");
    @import url("http://www.cesr.org/sites/all/modules/mollom/mollom.css?oo0bhk");
    @import url("http://www.cesr.org/modules/node/node.css?oo0bhk");
    @import url("http://www.cesr.org/sites/all/modules/views/css/views.css?oo0bhk");
    @import url("http://www.cesr.org/sites/all/modules/media/modules/media_wysiwyg/css/media_wysiwyg.base.css?oo0bhk");
    """
    
    console.log "DATA"
    
    obj = css.parse data.toString!, silent: true, source: u
    obj.stylesheet.rules |> each (it) -> console.log it
    obj.stylesheet.rules |> filter (it) -> /url/.test it.import |> each (it) -> console.log it
    
    (err, resp, body) <~ request u
    through err if err?
    $ = cheerio.load body.to-string!, 'utf-8'
    $ 'style[src!=""]' .each -> console.log $(this).html()

show-font-face = ->
    data2 = """
    ,
    @font-face{font-family:"Segoe UI";font-style:normal;font-weight:normal;src:local("Segoe UI"),
    url(//static-spartan-eus-s-msn-com.akamaized.net/_h/7fed7cf6/webcore/fonts/SegoeUI/WestEuropean/Segoe-UI.woff) format('woff'),
    url(//static-spartan-eus-s-msn-com.akamaized.net/_h/5f222cb6/webcore/fonts/SegoeUI/WestEuropean/Segoe-UI.ttf) format('truetype')},
    @font-face{font-family:"Segoe UI Light";font-style:normal;font-weight:normal;src:local("Segoe UI Light"),
    url(//static-spartan-eus-s-msn-com.akamaized.net/_h/87b36317/webcore/fonts/SegoeUI/WestEuropean/Segoe-UI-Light.woff) format('woff'),
    url(//static-spartan-eus-s-msn-com.akamaized.net/_h/dca4446f/webcore/fonts/SegoeUI/WestEuropean/Segoe-UI-Light.ttf) format('truetype')},
    @font-face{font-family:"Segoe UI Semilight";font-style:normal;font-weight:normal;src:local("Segoe UI Semilight"),
    url(//static-spartan-eus-s-msn-com.akamaized.net/_h/322c7185/webcore/fonts/SegoeUI/WestEuropean/Segoe-UI-Semilight.woff) format('woff'),
    url(//static-spartan-eus-s-msn-com.akamaized.net/_h/c19cac16/webcore/fonts/SegoeUI/WestEuropean/Segoe-UI-Semilight.ttf) format('truetype')},
    @font-face{font-family:"Segoe UI Semibold";font-style:normal;font-weight:normal;src:local("Segoe UI Semibold"),
    url(//static-spartan-eus-s-msn-com.akamaized.net/_h/bcc75797/webcore/fonts/SegoeUI/WestEuropean/Segoe-UI-Semibold.woff) format('woff'),
    url(//static-spartan-eus-s-msn-com.akamaized.net/_h/6ce20e6e/webcore/fonts/SegoeUI/WestEuropean/Segoe-UI-Semibold.ttf) format('truetype')}
    """
    
    console.log "FONT-FACES"
    obj = css.parse data2.toString!, silent: true, source: u
    validator = (e) -> e.property == \src
    obj.stylesheet.rules |> map (.declarations) |> flatten |> filter validator |> each (it) -> console.log it.value

#show-imports!
show-font-face!
