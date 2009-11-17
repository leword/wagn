# = Wagn::Cache
# 
# A wrapper around Rails.cache that lets you run separate "logical" stores 
# ( a store for each rails environment, a store for each wagn in multihost environment )
# within the main rails store, and expire each logical store separately.
#
#   Wagn.cache = Wagn::Cache.new Rails.cache, "#{System.host}/#{RAILS_ENV}" 
#  
module Wagn
  mattr_accessor :cache

  module Cache
    class Base
      def initialize( store, prefix )
        @store = store
        @local = Hash.new
        @prefix = prefix + '/'
      end
    
      def read key 
        fetch_local( key ) do
          @store.read( @prefix + key )
        end
      end
    
      def write key, value
        @local[key] = value
        @store.write( @prefix + key, value )
      end
    
      def fetch key, &block   
        fetch_local( key ) do 
          @store.fetch( @prefix + key, &block )
        end
      end   
      
      def delete key
        @local.delete key
        @store.delete( @prefix + key )
      end             
         
      def reset_local
        @local = {}
      end
      
      private
      def fetch_local key
        if @local.has_key?(key)
          @local[key]    
        else
          val = yield
          @local[key] = val
        end
      end
    end
    
    class Main < Base
      def initialize( store, prefix )
        @store = store   
        @local = Hash.new
        @original_prefix = prefix + '/'
        @cache_id = @store.fetch( @original_prefix + "cache_id" ) do
          self.class.generate_cache_id
        end
        @prefix = @original_prefix + @cache_id + "/"
      end
    
      def reset                                    
        reset_local
        @cache_id = self.class.generate_cache_id
        @store.write( @original_prefix + "cache_id", @cache_id )
        @prefix = @original_prefix + @cache_id + "/"
      end
    
      def self.generate_cache_id
        ((Time.now.to_f * 100).to_i).to_s
      end
    end
    
    def self.expire_card( key )
      Card.cache.delete key
      Slot.cache_keys.each do |viewname|
        Slot.cache.delete "#{key}/#{viewname}"
      end

      # legacy                             
      begin
        Card.fetch( key ).expire_all
      rescue
      end
    end
  end
end

Card.send :mattr_accessor, :cache
