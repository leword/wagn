Wagn::Hook::Card.register :before_save, { :type => "Pattern" } do |card|     
  begin
    spec = JSON.parse( card.content ).symbolize_keys        
  rescue Exception=>e
    # FIXME: better logger interface?
    ActiveRecord::Base.logger.warn("Invalid JSON #{card.content} for card #{card.name}")
  end
  if spec
    card.pattern_spec_key = Wagn::Pattern.key_for_spec( spec )
  end
end

