module Wagn
  module Exceptions
    Error               = Class.new StandardError
    NotFound            = Class.new Error
    PermissionDenied    = Class.new Error
    Oops                = Class.new Error
    RecursiveTransclude = Class.new Error
    WqlError            = Class.new Error
  end
  
  # 
  # # FIXME: this is here because errors defined in permissions break without it? kinda dumb
  # class ::Card::CardError < Wagn::Error   
  #   attr_reader :card
  #   def initialize(card)
  #     @card = card
  #     super build_message 
  #   end    
  # 
  #   def build_message
  #     "#{@card.name} has errors: #{@card.errors.full_messages.join(', ')}"
  #   end
  # end
  
end

  
