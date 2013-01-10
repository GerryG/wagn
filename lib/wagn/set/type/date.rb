module Wagn
  module Set::Type::Date
    include Sets

    format :base

    define_view :editor, :type=>'date' do |args|
      form.text_field :content, :class=>'date-editor'
    end
  end
end
