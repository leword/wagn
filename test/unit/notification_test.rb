require File.dirname(__FILE__) + '/../test_helper'   
require 'timecop'    

class NotificationTest < ActiveSupport::TestCase  
  FUTURE = Time.local(2020,1,1,0,0,0)
  
  def self.custom_test_data
    User.as(:wagbot) do
      # have these items created way in the past

      Timecop.freeze(FUTURE - 1.day) do
        # fwiw Timecop is apparently limited by ruby Time object, which goes only to 2037 and back to 1900 or so.
        #  whereas DateTime can represent all dates. 

        john_account = ::User.create! :login=>"john",:email=>'john@user.com', :status => 'active', :password=>'john_pass', :password_confirmation=>'john_pass', :invite_sender=>User[:wagbot]
        sara_account = ::User.create! :login=>"sara",:email=>'sara@user.com', :status => 'active', :password=>'sara_pass', :password_confirmation=>'sara_pass', :invite_sender=>User[:wagbot]

        Card.create! :name=>"John", :type=> "User", :extension=>john_account
        Card.create! :name=>"Sara", :type=> "User", :extension=>sara_account       

        Card.create! :name => "Sara Watching+*watchers",  :content => "[[Sara]]"
        Card.create! :name => "All Eyes On Me+*watchers", :content => "[[Sara]]\n[[John]]"
        Card.create! :name => "John Watching", :content => "{{+her}}"
        Card.create! :name => "John Watching+*watchers",  :content => "[[John]]"
        Card.create! :name => "John Watching+her" 
        Card.create! :name => "No One Sees Me" 

        Card.create! :name => "Optic", :type => "Cardtype"
        Card.create! :name => "Optic+*watchers", :content => "[[Sara]]"
        Card.create! :name => "Sunglasses", :type=>"Optic", :content=>"{{+tint}}"                          
        Card.create! :name => "Sunglasses+tint"

        # TODO: I would like to setup these card definitions with something like Cucumbers table feature.
      end
    end
  end  

  def setup                             
    Timecop.freeze(FUTURE)  # make sure we're ahead of all the test data
    super
  end
  
  context "Card#watchers" do
    setup do
      NotificationTest.custom_test_data
    end
    
    should "return users watching this card specifically" do
      assert_equal ["Sara", "John"], Card["All Eyes On Me"].watchers
    end
    
    should "return users watching cards of this type" do
      assert_equal ["Sara"], Card["Sunglasses"].watchers
    end
    
    context "card_watchers" do
      should "return users watching this card specifically" do
        assert_equal ["Sara", "John"], Card["All Eyes On Me"].card_watchers
      end
    end
    
    context "type_watchers" do
      should "return users watching cards of this type" do
        assert_equal ["Sara"], Card["Sunglasses"].type_watchers
      end
    end    
  end
    
  context "Card Changes" do
    setup do
      NotificationTest.custom_test_data
      User.as(:john)           
    end
    
    should "send notifications of edits" do
      Mailer.expects(:deliver_change_notice).with( User.find_by_login('sara'), Card["Sara Watching"], "edited", "Sara Watching" )
      Card["Sara Watching"].update_attributes :content => "A new change"
    end
                                    
    should "send notifications of additions" do
      new_card = Card.new :name => "Microscope", :type => "Optic"
      Mailer.expects(:deliver_change_notice).with( User.find_by_login('sara'), new_card,"added", "Optic"  )
      new_card.save!
    end 
    
    should "send notification of updates" do
      Mailer.expects(:deliver_change_notice).with( User.find_by_login('sara'), Card["Sunglasses"], "updated", "Optic")
      Card["Sunglasses"].update_attributes :type => "Basic"
    end
    
    should "not send notification to author of change" do
      Mailer.expects(:deliver_change_notice).with( User.find_by_login('sara'), Card["All Eyes On Me"],"edited", "All Eyes On Me")
      Card["All Eyes On Me"].update_attributes :content => "edit by John"
      # note no message to John
    end
  end
end