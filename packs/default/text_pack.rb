class Wagn::Renderer::Text
  define_view :show do |args|
    self.render(params[:view] || :naked)
  end
  
  define_view :naked do |args|
    HTMLEntities.new.decode strip_tags(process_content(_render_raw))
  end
end
