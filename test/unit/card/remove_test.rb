require File.dirname(__FILE__) + '/../../test_helper'
class Card::RemoveTest < ActiveSupport::TestCase
  def setup
    super
    @a = Card.find_by_name("A")
  end

     
  # I believe this is here to test a bug where cards with certain kinds of references
  # would fail to delete.  probably less of an issue now that delete is done through
  # trash.  
  def test_remove
    assert @a.destroy!, "card should be destroyable"
    assert_nil Card.find_by_name("A")
  end
         
  def test_recreate_plus_card_name_variant
    Card.create( :name => "rta+rtb" ).destroy
    Card["rta"].update_attributes :name=> "rta!"
    c = Card.create! :name=>"rta!+rtb"
    assert Card["rta!+rtb"]
    assert !Card["rta!+rtb"].trash
    assert !Card.find(:first, :conditions=>"name=E'rtb*trash'")
  end   
  
  
  def test_multiple_trash_collision
    Card.create( :name => "alpha" ).destroy
    3.times do
      b = Card.create( :name => "beta" )
      b.name = "alpha"
      assert b.save! 
      b.destroy
    end
  end
  
end

