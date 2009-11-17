require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Card do     
  context "fetch" do
    before do    
      Wagn.cache.reset
    end

    it "returns and caches existing cards" do
      Card.fetch("A").should be_instance_of(Card::Basic)
      Card.cache.read("A").should be_instance_of(Card::Basic)
      Card.should_not_receive(:find_by_key)
      Card.fetch("A").should be_instance_of(Card::Basic)
    end            
    
    it "returns nil and caches missing cards" do
      Card.fetch("Zork").should be_nil
      Card.cache.read("Zork").missing.should be_true
      Card.fetch("Zork").should be_nil
    end
    
    it "returns nil and caches trash cards" do
      User.as(:wagbot)
      Card["A"].destroy!
      Card.fetch("A").should be_nil
      Card.should_not_receive(:find_by_key)
      Card.fetch("A").should be_nil
    end
    
    it "returns and does not cache builtin cards" do
      Card.fetch("*head").should be_instance_of(Card::Basic)
      Card.cache.read("*head").should be_nil
    end
    
    it "returns and does not cache virtual cards" do
      # code for this is written.  lazed on test.
      pending
    end          
    
    it "does not recurse infinitively on template templates" do
      Card.fetch("*rform+*rform").should be_nil
    end
    
  end
  
  context "cached cards" do
    it "expire on save" do
      User.as :wagbot
      Card.fetch("A").should be_instance_of(Card::Basic)
      a = Card.cache.read("A")
      a.should be_instance_of(Card::Basic)
      a.save!
      Card.cache.read("A").should be_nil
    end
    
    it "expire when dependents are updated" do
      # several more cases of expiration really should be tested.
      # they're not tested under CachedCard and the hook to call Card.cache expirations
      # is essentially the same.
      pending
    end
  end
end