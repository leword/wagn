require_dependency 'slot_helpers'

class Slot
  cattr_accessor :cache 
  cattr_accessor :cache_keys
  self.cache_keys = [ :view_content, :line_content, :footer ]
  
  include SlotHelpers  
  cattr_accessor :max_char_count
  self.max_char_count = 200
  attr_reader :card, :context, :action, :renderer, :template
  attr_accessor :editor_count, :options_need_save, :state, :requested_view, :js_queue_initialized,  
    :transclusions, :position, :renderer, :form, :superslot, :char_count, :item_format, :type, :renders, 
    :start_time, :skip_autosave, :config, :slot_options
  attr_writer :form 

  VIEW_ALIASES = { 
    :view => :open,
    :card => :open,
    :line => :closed,
  }
   
  def initialize(card, context="main_1", action="view", template=nil, opts={} )
    @card, @context, @action, @template, = card, context.to_s, action.to_s, (template||StubTemplate.new)
    # FIXME: this and context should all be part of the context object, I think.
    # In any case I had to use "slot_options" rather than just options to avoid confusion with lots of 
    # local variables named options.
    @slot_options = {
      :relative_content => {},
      :main_content => nil,
      :transclusion_view_overrides => nil,
      :renderer => Renderer.new
    }.merge(opts)
    
    @renderer = @slot_options[:renderer]
    @context = "main_1" unless @context =~ /\_/
    @position = @context.split('_').last    
    @char_count = 0
    @subslots = []  
    @state = 'view'
    @renders = {}
  end

  def subslot(card, &proc)
    # Note that at this point the subslot context, and thus id, are
    # somewhat meaningless-- the subslot is only really used for tracking position.
    new_slot = self.class.new(card, context+"_#{@subslots.size+1}", @action, @template, :renderer=>@renderer)
    new_slot.state = @state
    @subslots << new_slot 
    new_slot.superslot = self
    new_slot.position = @subslots.size
    new_slot
  end
  
  def root
    superslot ? superslot.root : self
  end

  def form
    @form ||= begin
      # NOTE this code is largely copied out of rails fields_for
      options = {} # do I need any? #args.last.is_a?(Hash) ? args.pop : {}
      block = Proc.new {}
      builder = options[:builder] || ActionView::Base.default_form_builder
      card.name.gsub!(/^#{root.card.name}\+/, '+') if root.card.new_record?  ##FIXME -- need to match other relative inclusions.
      fields_for = builder.new("cards[#{card.name.pre_cgi}]", card, @template, options, block)       
    end
  end    
  
  def full_field_name(field)   
    form.text_field(field).match(/name=\"([^\"]*)\"/)[1] 
  end

  def wrap_content( content="" )
    %{<span class="#{canonicalize_view(self.requested_view)}-content content editOnDoubleClick">} +
       content.to_s + 
    %{</span><!--[if IE]>&nbsp;<![endif]-->} 
  end    
  
  def js
    @js ||= SlotJavascript.new(self)
  end
         
  # FIXME: passing a block seems to only work in the templates and not from
  # internal slot calls, so I added the option passing internal content which
  # makes all the ugly block_given? ifs..                                                 
  def wrap(action="", args={}) 
    render_slot = args.key?(:add_slot) ? args.delete(:add_slot) : !request.xhr? 
    content = args.delete(:content)
     
    open_slot, close_slot = "",""

    result = ""
    if render_slot
      case action.to_s
        when 'content';    css_class = 'transcluded'
        when 'exception';  css_class = 'exception'    
#          when 'nude'   ;   css_class = 'nude-slot'
        else begin
          css_class = 'card-slot '      
          css_class << (action=='closed' ? 'line' : 'paragraph')
          css_class << ' full' if (context=~/main/ or (action!='view' and action!='closed'))
          css_class << ' sidebar' if context=~/sidebar/
        end
      end       
      
      css_class << " wrapper cardid-#{card.id} type-#{card.type}" if card
      
      attributes = { 
        :cardId   => (card && card.id),
        :style    => args[:style],
        :view     => args[:view],
        :item     => args[:item],
        :base     => args[:base], # deprecated
        :class    => css_class,
        :position => position
      }
      
      slot_attr = attributes.map{ |key,value| value && %{ #{key}="#{value}" }  }.join
      open_slot = "<div #{slot_attr}>"
      close_slot= "</div>"
    end
    
    if block_given? 
      if (Rails::VERSION::MAJOR >=2 && Rails::VERSION::MINOR >= 2)
        args = nil
        @template.output_buffer ||= ''   # fixes error in CardControllerTest#test_changes
      else
        args = proc.binding
      end
      @template.concat open_slot, *args
      yield(self)
      @template.concat close_slot, *args
      return ""
    else
      return open_slot + content + close_slot
    end
  end
  
  def cache_action(viewname)
    raise "invalid slot cache key '#{viewname}'" unless self.class.cache_keys.include?(viewname)
    Slot.cache.fetch( "#{card.key}/#{viewname}" ) do
      yield
    end
  end
  
  def deny_render?(action)
    case
      when [:deny_view, :edit_auto, :open_missing, :closed_missing].member?(action);
        false
      when card.new_record?
        false # need create check...
      when [:edit, :edit_in_form, :multi_edit].member?(action)
        !card.ok?(:edit) and :deny_view #should be deny_edit
      else
        !card.ok?(:read) and :deny_view
    end
  end

  def canonicalize_view( view )
    view = view.to_sym
    VIEW_ALIASES[view.to_sym] || view
  end

  def render(action, args={})      
    #warn "<render(#{card.name}, #{@state}).render(#{action}, item=>#{args[:item]})"
    
    rkey = self.card.name + ":" + action.to_s
    root.renders[rkey] ||= 1 
    root.renders[rkey] += 1 unless [:name, :link].member?(action)
    #root.start_time ||= Time.now.to_f

    ok_action = case
      when root.renders[rkey] > System.max_renders                    ; :too_many_renders
      #when (Time.now.to_f - root.start_time) > System.max_render_time ; :too_slow
      when denial = deny_render?(action)                              ; denial
      else                                                            ; action
    end

    w_content = nil
    result = case ok_action

    ###-----------( FULL )
      when :new
        w_content = render_partial('views/new')
        
      when :open, :view, :card
        @state = :view; self.requested_view = 'open'
        # FIXME: accessing params here is ugly-- breaks tests.
        #w_action = (@template.params[:view]=='content' && context=="main_1") ? 'nude' : 'open'
        w_action = 'open'
        w_content = render_partial('views/open')

      when :closed, :line    
        @state = :line; w_action='closed'; self.requested_view = 'closed'
        w_content = render_partial('views/closed')  # --> slot.wrap_content slot.render( :expanded_line_content )   
        
    ###----------------( NAME)
    
      #when :link;   link_to_page card.name, card.name, :class=>"cardname-link #{card.new_record? ? 'wanted-card' : 'known-card'}"
      when :link;
        opts = {:class=>"cardname-link #{(card.new_record? && !card.virtual?) ? 'wanted-card' : 'known-card'}"}
        opts[:type] = slot.type if slot.type 
        link_to_page card.name, card.name, opts
      when :name;   card.name
      when :key;    card.name.to_key
      when :linkname;  Cardname.escape(card.name)
      when :titled;
        content_tag( :h1, less_fancy_title(card.name) ) + self.render( :content )
        
      when :rss_titled;                                                         
        # content includes wrap  (<object>, etc.) , which breaks at least safari rss reader.
        content_tag( :h2, less_fancy_title(card.name) ) + self.render( :expanded_view_content )

      when :rss_change
        w_action = self.requested_view = 'content'
        render_partial('views/change')
        
      when :change;
        w_action = self.requested_view = 'content'
        w_content = render_partial('views/change')

    ###---(  CONTENT VARIATIONS ) 
      #-----( with transclusions processed )
      when :content;  
        w_action = self.requested_view = 'content'  
        c = self.render( :expanded_view_content)
        w_content = wrap_content(((c.size < 10 && strip_tags(c).blank?) ? "<span class=\"faint\">--</span>" : c))

      when :expanded_view_content, :naked, :raw # raw is DEPRECATED
        @state = 'view'
        expand_transclusions(  cache_action('view_content') {  card.post_render( render(:open_content)) } )

      when :expanded_line_content
        expand_transclusions(  cache_action('line_content') { render(:closed_content) } )


      #-----( without transclusions processed )

      when :closed_content;   render_card_partial(:line)   # in basic case: --> truncate( slot.render( :open_content ))
      when :open_content;     render_card_partial(:content)  # FIXME?: 'content' is inconsistent
      when :naked_content
        if card.virtual? and card.builtin?  # virtual? test will filter out cached cards (which won't respond to builtin)
          template.render :partial => "builtin/#{card.name.gsub(/\*/,'')}" 
        else
          @renderer.render( card, args.delete(:content) || "", update_refs=card.references_expired)
        end
        
    ###---(  EDIT VIEWS ) 

      when :edit;  @state=:edit;  card.hard_template ? render(:multi_edit) : content_field(slot.form)
        
      when :multi_edit;
        @state=:edit 
        args[:add_javascript]=true
        hidden_field_tag( :multi_edit, true) +
        expand_transclusions( render(:naked_content) )

      when :edit_in_form
        render_partial('views/edit_in_form', args.merge(:form=>form))
          
      ###---(  EXCEPTIONS ) 
      
      when :deny_view, :edit_auto, :too_slow, :too_many_renders, :open_missing, :closed_missing
          render_partial("views/#{ok_action}", args)

      when :blank; 
        ""

      else; "<strong>#{card.name} - unknown card view: '#{ok_action}'</strong>"
    end
    if w_content
      args[:add_slot] = true unless args.key?(:add_slot)
      result = wrap(w_action, { :content=>w_content }.merge(args))
    end
    
#      result ||= "" #FIMXE: wtf?
    result << javascript_tag("setupLinksAndDoubleClicks();") if args[:add_javascript]
    result
  rescue Card::PermissionDenied=>e
    return "Permission error: #{e.message}"
    
  end

  def expand_transclusions(content, args={}) 
    #return ("skip(#{card.name}):"+content) 
    if card.name.template_name?          
      # KLUGILICIOIUS: if we leave the {{}} transclusions intact they may get processed by
      #  an outer card expansion-- causing weird rendering oddities.  the bogus thing
      #  seems to work ok for now.
      return content.gsub(/\{\{/,'{<bogus />{').gsub(/\}\}/,'}<bogus />}')
    end
    #content = "noskip(#{card.name}):" + content
    content.gsub!(Chunk::Transclude::TRANSCLUDE_PATTERN) do  
      if @state==:line && self.char_count > Slot.max_char_count
        ""
      else 
        begin
          match = $~
          tname, options = Chunk::Transclude.parse(match)     
          if view_map = root.slot_options[:transclusion_view_overrides]
            if translated_view = view_map[ canonicalize_view( options[:view] )]
              options[:view] = translated_view
            end
          end
          fullname = tname+'' #weird.  have to do this or the tname gets busted in the options hash!!
          #warn "options for #{tname}: #{options.inspect}"
          fullname.to_absolute(options[:base]=='parent' ? card.name.parent_name : card.name)
          fullname.gsub!('_user', User.current_user.card.name)
          options[:fullname] = fullname
          options[:showname] = tname.to_show(fullname)
          #logger.info("absolutized tname and now have these transclusion options: #{options.inspect}")


          if fullname.blank?  
             # process_transclusion blows up if name is nil
            "{<bogus/>{#{fullname}}}" 
          elsif fullname == "_main"
            %{<div id="main" context="main">#{slot_options[:main_content]}</div>}
          else                                             
            cargs = { :name=>fullname, :type=>options[:type] }
            #@template.controller.params[tname.gsub(/\+/,'_')]).present?
            if (specified_content = root.slot_options[:relative_content][tname.gsub(/\+/,'_')]).present?
              cargs[:content] = specified_content
            end

            tcard = case
              when @state==:edit
                (Card.find_by_name( fullname ) || Card.find_virtual( fullname ) ||  Card.new( cargs ))
              else
                CachedCard.get fullname
              end
        
            #warn("sending these options for processing: #{options.inspect}")
       
            tcontent = process_transclusion( tcard, options ) 
            self.char_count += (tcontent ? tcontent.length : 0)
                                    
            if size = options[:size] 
              size = (size.to_s == "full" ? "" : "_#{size}")
              tcontent = tcontent.gsub(/_medium(\.\w+\")/,"#{size}"+'\1')
            end
            
            tcontent
            
               
          end
        rescue Card::PermissionDenied
          ""
        end
      end
    end  
    content     
  end
     
  def render_partial( partial, locals={} )
    locals =  { :card=>card, :slot=>self }.merge(locals)
    StubTemplate===@template ? render_stub(partial, locals) : @template.render(:partial=>partial, :locals=>locals)
  end

  def card_partial(action) 
    # FIXME: I like this method name better- maybe other calls should resolve here instead
    @template.partial_for_action(action, card)
  end
  
  def render_card_partial(action, locals={})
     render_partial card_partial(action), locals
  end
  
  def process_transclusion( card, options={} )  
    #warn("<process_transclusion card=#{card.name} options=#{options.inspect}")
    subslot = subslot(card)  
    old_slot, @template.controller.slot = @template.controller.slot, subslot

    # set item_format;  search cards access this variable when rendering their content.
    subslot.item_format = options[:item] if options[:item]
    subslot.type = options[:type] if options[:type]
                           
    
    # FIXME! need a different test here   
    new_card = card.new_record? && !card.virtual?
    
    state, vmode = @state.to_sym, (options[:view] || :content).to_sym      
    subslot.requested_view = vmode
    action = case
      when [:name, :link, :linkname].member?(vmode)  ; vmode
      when state==:edit                   ; card.virtual? ? :edit_auto : :edit_in_form   
      when new_card                       
        case   
          when vmode==:naked; :blank
          when state==:line;  :closed_missing
          else ;              :open_missing
        end
      when state==:line                   ; :expanded_line_content
      else                                ; vmode
    end

    #logger.info("<transclusion_case: state=#{state} vmode=#{vmode} --> Action=#{action}, Option=#{options.inspect}")

    result = subslot.render action, options
    @template.controller.slot = old_slot
    result
  end   
  
  def method_missing(method_id, *args, &proc) 
    # silence Rails 2.2.2 warning about binding argument to concat.  tried detecting rails 2.2
    # and removing the argument but it broken lots of integration tests.
    ActiveSupport::Deprecation.silence { @template.send(method_id, *args, &proc) }
  end

  
  def render_stub(partial, locals={})
    raise("Invalid partial") if partial.blank? 
    case partial
      when "card/view"
        %{\n<div class="view">\n} + wrap_content( render( :expanded_view_content ))+ %{\n</div>\n}
      when "card/line"
        %{\n<div class="view">\n} + wrap_content( render(:expanded_line_content) ) + %{\n</div>\n}
      when "basic/content"
        render :naked_content
      when "basic/line"
        truncatewords_with_closing_tags( render( :custom_view ))
      else
        "No Stub for #{partial}"
    end
  end
end   


# For testing/console use of a slot w/o controllers etc.
class StubTemplate      
  include ActionView::Helpers::SanitizeHelper
  attr_accessor :indent, :slot
  # for testing & commandline use  
  # not totally happy with this..    

  def self.full_sanitizer
    @full_sanitizer ||= HTML::FullSanitizer.new
  end
  
   
  def params
    return {}
  end
  
  def controller
    @controller ||= (Struct.new(:slot)).new(nil)
  end 
  
  def partial_for_action(action, card) 
    "#{card.type.to_s.downcase}/#{action}"
  end  
  
end


