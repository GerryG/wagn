# -*- encoding : utf-8 -*-

view :editor do |args|
  form.text_area :content, :rows=>15, :class=>'card-content'
end

view :closed_content do |args|
  ''
end

def clean_html?
  false
end
