require! {
    css
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
obj = css.parse data.toString!, silent: true, source: 'http://www.cesr.org'
console.log obj
