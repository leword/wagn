module Card
	class Pointer < Base

    class << self
      def options_card(tagname)
        card = ::User.as(:wagbot) do
	        Card.fetch_real("#{tagname}+*options")
	      end
	      (card && card.type=='Search') ? card : nil
	    end
    end


	  def cacheable?
      false
    end
	  	  
	  def add_reference( cardname )
	    unless pointees.include? cardname
	      self.content = (pointees + [cardname]).reject{|x|x.blank?}.map{|x| "[[#{x}]]" }.join("\n")
  	    save!
      end
    end 
	                                   
	  def remove_reference( cardname ) 
	    if pointees.include? cardname
  	    self.content = (pointees - [cardname]).map{|x| "[[#{x}]]"}.join("\n")
  	    save!
	    end
    end
	    
	  def option_text(option)
	    name = System.setting('*option label') || System.setting("#{self.name.tag_name}+*option label") || 'description'
	    textcard = Card.fetch_real(option+'+'+name)
	    textcard ? textcard.content : nil
	  end
	    
	  def pointees=(items)
	    items=items.values if Hash===items 
	    self.content = [items].flatten.reject{|x|x.blank?}.map{|x| "[[#{x}]]"}.join("\n")
    end  
    
    def pointee=(item)
      self.pointees = [item]
    end  
	  
	  def item_type
	    opt = options_card
	    opt ? opt.get_spec[:type] : nil
	  end
	  
	  def options_card
	    tagname = self.name.tag_name or return nil
	    self.class.options_card(tagname)
	  end
	  
	  def options(limit=50)
      (c=self.options_card) ? c.search(:limit=>limit) : Card.search(:sort=>'alpha',:limit=>limit)
    end
    
    def limit
      card = System.setting("#{self.name.tag_name}+*max") or return nil
      card.content.strip.to_i
    end    
    
    def autoname
      System.setting("#{self.name.tag_name}+*autoname")
    end
	end
end