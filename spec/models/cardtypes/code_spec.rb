require File.dirname(__FILE__) + '/../../spec_helper'

describe Card::Code, "create" do	
	before(:each) do 
	  User.as :admin
		Card::Code.create :name=>"New Code"
	end
	
	it "should have the right class" do
		Card.find_by_name("New Code").class.should == Card::Code
	end
end