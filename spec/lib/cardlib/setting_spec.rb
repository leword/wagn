require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Card do
  before do
    User.as(:wagbot)  
    Wagn.cache.reset
  end
  
  context "settings" do
    it "retrieves pattern based value" do
      Card.create :name => "Book cards", :type => "Pattern", :content => "{\"type\": \"Book\"}"
      Card.create :name => "Book cards+*new", :content => "authorize"
      Card.new( :type => "Book" ).setting('new').should == "authorize"
    end                                          
    
    it "retrieves default values" do
      Card.create :name => "*default+*new", :content => "lobotomize"
      Card.new( :type => "Basic" ).setting('new').should == "lobotomize"
    end                                                                 
    
    it "retrieves single values" do
      Card.create! :name => "banana+*+*edit", :type=>'Phrase', :content => "pebbles"
      Card["banana+*+*edit"].should be_instance_of(Card::Phrase)
      Card["banana"].setting('edit').should == "pebbles"
    end
  end
  
end