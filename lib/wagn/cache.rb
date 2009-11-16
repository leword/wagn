module Wagn
  mattr_accessor :cache
  
  class Cache
    def initialize( store, static_prefix )
      @store = store
      @static_prefix = static_prefix + '/'
      @cache_id = @store.fetch( @static_prefix + "cache_id" ) do
        self.class.generate_cache_id
      end
      @prefix = @static_prefix + @cache_id + "/"
    end

    def read key
      @store.read( @prefix + key )
    end
    
    def write key, value
      @store.write( @prefix + key, value )
    end
    
    def fetch key, &block
      @store.fetch( @prefix + key, &block )
    end                
    
    def reset                                    
      @cache_id = self.class.generate_cache_id
      @store.write( @static_prefix + "cache_id", @cache_id )
      @prefix = @static_prefix + @cache_id + "/"
    end
    
    def self.generate_cache_id
      ((Time.now.to_f * 100).to_i).to_s
    end
  end
end