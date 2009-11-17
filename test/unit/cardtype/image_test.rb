require File.dirname(__FILE__) + '/../../test_helper'
class Card::ImageTest < ActiveSupport::TestCase       
  # required to use ActionController::TestUploadedFile 
  require 'action_controller'
  require 'action_controller/test_process.rb'
  
  def test_image_creation
    path = "#{RAILS_ROOT}/test/fixtures/mao2.jpg"
    mimetype = "image/jpeg"
      
    card_image = CardImage.create :uploaded_data => ActionController::TestUploadedFile.new(path, mimetype) 
    @c=Card::Image.create( :name => "Bananamaster", :attachment_id=>card_image.id )

    assert_instance_of Card::Image, @c
  end
  
end
