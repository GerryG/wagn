require File.expand_path('../../test_helper', File.dirname(__FILE__))
class Wagn::Set::Type::ImageTest < ActiveSupport::TestCase
  #require 'action_controller'


  def setup
    super
    setup_default_account
  end

  def test_image_creation

    Rails.logger.warn "user? #{Account.as_card.inspect}, #{Account.current.inspect}"
    @c=Card.create :name => "Bananamaster", :typecode=>'image',
                   :attach=>File.new("#{Rails.root}/test/fixtures/mao2.jpg")
    @c.attach_file_name == 'Bananamaster.jpg'
  end

end
