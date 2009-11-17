module Cardlib
  module Settings
    def setting setting_name
      # look for single definition
      if setting_card = Card.fetch( "#{self.name}+*+*#{setting_name}" )
        return setting_card.content
      end
      
      # look for pattern
      Wagn::Pattern.keys_for_card( self ).each do |key|
        if pattern_card = Card.find_by_pattern_spec_key( key )
          if setting_card = Card.fetch( "#{pattern_card.name}+*#{setting_name}" ) 
            return setting_card.content
          end
        end
      end
      
      # look for default
      if setting_card = Card.fetch( "*default+*#{setting_name}" ) 
        return setting_card.content
      end
            
      "no setting"
    end
  end
end