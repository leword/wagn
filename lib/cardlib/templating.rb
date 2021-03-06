module Cardlib 
  module Templating  
    
    def self.included(base)   
      super
      base.extend(ClassMethods)
    end
        
    module ClassMethods
      # def template(name)
      #   right_template(name) || type_template(name) || default_template
      # end
      # 
      # def right_template(name='')
      #   return nil unless name and name.junction?
      #   #(tag = find_template(name.tag_name) and find_template(Cardtype.name_for(tag.type)+"+*rform")) || 
      #   find_template(name.tag_name+"+*rform")
      # end
      # 
      # def type_template(name, type=nil)
      #   ## OPTIMIZE!!!
      #   multi_type_template(name) || single_type_template #(name)
      # end
      # 
      # def single_type_template(name)
      #   card = find_template(name)
      #   card && tform(Cardtype.name_for(self.type)) || tform('Basic')
      # end
      # 
      # def multi_type_template(name)
      #   if name and !name.simple? 
      #     trunk = find_template(name.trunk_name) or return nil
      #     tag   = find_template(name.tag_name)   or return nil
      #     tform "#{Cardtype.name_for(trunk.type)}+#{Cardtype.name_for(tag.type)}"       
      #   end
      # end
      # 
      # def tform(name)
      #   find_template(name+'+*type+*content')
      # end
      # 
      # def find_template(name)
      #   User.as(:wagbot) { CachedCard.get_real(name) }
      # end
      # 
      # def default_template
      #   # FIXME -- this should be out by 1.0
      #   # this last case where we create a dummy defaults card should
      #   # ONLY come up during migration from pre templating wagns
      #   # -- after that we should always have a type card      
      #   Card::Basic.new(:content=>"", 
      #     :permissions=>[Permission.new(:task=>'read',:party=>::Role[:anon])] + 
      #       [:edit,:comment, :delete].map{|t| Permission.new(:task=>t.to_s, :party=>::Role[:auth])}
      #    )        
      # end        
    end
    
    
    #------( this template governs me )
    
    # def template 
    #   @template ||= right_template || type_template || self.class.default_template  
    # end
    # 
    # def right_template
    #   @right_template ||= self.class.right_template(name)
    # end
    # 
    # def type_template
    #   @type_template ||= self.class.multi_type_template(name) || single_type_template
    # end
    # 
    # def hard_template
    #   nil
    #   #template.hard_template? ? template : nil
    # end
    # 
    # def single_type_template
    #   self.class.tform(Cardtype.name_for(self.type)) || self.class.tform('Basic')
    # end
    # 
    # def find_template(name)
    #   self.class.find_template(name)
    # end

    
    
    #-----( ... and I govern these cards )
    def hard_templatees
      if wql=hard_templatee_wql
        User.as(:wagbot)  {  Wql.new(wql).run  }
      else
        []
      end
    end    

    # FIXME: content settings -- do we really need the reference expiration system?
    def expire_templatee_references
	    return unless respond_to?('references_expired')
      if wql=hard_templatee_wql
        condition = User.as(:wagbot) { Wql::CardSpec.build(wql.merge(:return=>"condition")).to_sql }
        card_ids_to_update = connection.select_rows("select id from cards t where #{condition}").map(&:first)
        card_ids_to_update.each_slice(100) do |id_batch|
          connection.execute "update cards set references_expired=1 where id in (#{id_batch.join(',')})"
        end
      end
    end

    def right_template
      (template && template.right_template?) ? template : nil
    end

    def hard_template
      (template && template.hard_template?) ? template : nil
    end
    
    def template
      @template ||= setting_card('content')
    end
    
    def content_templated?
      hard_template
    end        
    
    private
    # FIXME: remove after adjusting expire_templatee_references to content_settings
    def hard_templatee_wql
      if hard_template? and c=CachedCard.get(name.trunk_name) and c.type == "Set"
        wql = c.get_spec
      end
    end
      
  end
end
