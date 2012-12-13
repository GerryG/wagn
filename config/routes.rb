FORMATS = 'html|json|xml|rss|kml|css|txt|text|csv' unless defined? FORMATS

Wagn::Application.routes.draw do

  if !Rails.env.production? && Object.const_defined?( :JasmineRails )
    mount Object.const_get(:JasmineRails).const_get(:Engine) => "/specs"
  end

  # these file requests should only get here if the file isn't present.
  # if we get a request for a file we don't have, don't waste any time on it.
  #FAST 404s
  match ':asset/:foo' => 'application#fast_404', :constraints =>
    { :asset=>/assets|images?|stylesheets?|javascripts?/, :foo => /.*/ }

  # RESTful actions, card#action dispatches on request.method
  match '/' => 'card#action'
  match 'recent(.:format)' => 'card#action', :id => '*recent', :view => 'content'
  match '(/wagn)/:id(.:format)' => 'card#action'

  match '/files/(*id)' => 'card#read_file'

  match 'new/:type' => 'card#action', :view => 'new'

  match 'card/:view(/:id(.:format)(/:attribute))' => 'card#action',
    :constraints => { :view=> /new|changes|options|related|edit/ }

  #match ':controller/:action(/:id(.:format)(/:attribute))' => "card#action"

  match '*id' => 'card#action', :view => 'bad_address'

end




