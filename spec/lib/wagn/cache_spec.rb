require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Wagn::Cache do
  before :each do
    @store = ActiveSupport::Cache::MemoryStore.new
    Wagn::Cache.should_receive("generate_cache_id").and_return("cache_id")
    @cache = Wagn::Cache.new @store, "prefix"
  end
  
  it "reads" do
    @store.should_receive(:read).with("prefix/cache_id/foo")
    @cache.read("foo")
  end
  
  it "writes" do
    @store.should_receive(:write).with("prefix/cache_id/foo", "val")
    @cache.write("foo", "val")
  end
  
  it "fetches" do
    block = Proc.new { "hi" }
    @store.should_receive(:fetch).with("prefix/cache_id/foo", &block)
    @cache.fetch("fetch", &block)
  end     
  
  it "resets" do    
    Wagn::Cache.should_receive("generate_cache_id").and_return("cache_id2")
    @cache.write("foo","bar")
    @cache.read("foo").should == "bar"
    @cache.reset
    @cache.read("foo").should be_nil
  end
end