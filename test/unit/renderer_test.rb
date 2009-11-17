require File.dirname(__FILE__) + '/../test_helper'

class RendererTest < ActiveSupport::TestCase
  def test_replace_references_should_work_on_inclusions_inside_links       
    card = Card.create!(:name=>"test", :content=>"[[test{{test}}]]"  )    
    assert_equal "[[test{{best}}]]", Renderer.new.replace_references( card, "test", "best" )
  end                                                                                                
end