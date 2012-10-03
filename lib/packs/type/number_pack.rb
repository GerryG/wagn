class Wagn::Renderer
  define_view :editor, :type=>'number' do |args|
    form.text_field :content, :class=>'number-editor'
  end
end
