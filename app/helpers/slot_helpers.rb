module SlotHelpers  
  
  
  def render_diff(card, *args)
    @renderer.render_diff(card, *args)
  end
  
  def notice 
    %{<span class="notice">#{controller.notice}</span>}
  end

  def id(area="") 
    area, id = area.to_s, ""  
    id << "javascript:#{get(area)}"
  end  
  
  def parent
    "javascript:getSlotSpan(getSlotSpan(this).parentNode)"
  end                       
   
  def nested_context?
    context.split('_').length > 2
  end
   
  def get(area="")
    area.empty? ? "getSlotSpan(this)" : "getSlotElement(this, '#{area}')"
  end
   
  def selector(area="")   
    "getSlotFromContext('#{context}')";
  end             
 
  def card_id
    (card.new_record? && card.name)  ? Cardname.escape(card.name) : card.id
  end

  def editor_id(area="")
    area, eid = area.to_s, ""
    eid << context
    eid << (area.blank? ? '' : "-#{area}")
  end

  def edit_submenu(on)
    div(:class=>'submenu') do
      [[ :content,    true  ],
       [ :name,       true, ],
       [ :type,       !(card.type_template? || (card.type=='Cardtype' and ct=card.me_type and !ct.find(:all).empty?))],
       [ :inclusions, !(card.out_transclusions.empty? || card.template? || card.hard_template),         {:inclusions=>true} ]
       ].map do |key,ok,args|

        link_to_remote( key, 
          { :url=>url_for("card/edit", args, key), :update => ([:name,:type].member?(key) ? id('card-body') : id) }, 
          :class=>(key==on ? 'on' : '') 
        ) if ok
      end.compact.join       
     end  
  end

  def paging_params
    s = {}
    [:offset,:limit].each{|key| s[key] = params[key]}
    s[:offset] = s[:offset] ? s[:offset].to_i : 0
  	s[:limit]  = s[:limit]  ? s[:limit].to_i  : (context=='main_1' ? 50 : 20)
	  s
  end


  def url_for(url, args=nil, attribute=nil)
    url = "javascript:'/#{url}"
    url << "/#{escape_javascript(URI.escape(card_id.to_s))}" if (card and card_id)
    url << "/#{attribute}" if attribute   
    url << "?context='+getSlotContext(this)"
    url << "+'&' + getSlotOptions(this)"
    url << ("+'"+ args.map{|k,v| "&#{k}=#{escape_javascript(URI.escape(v.to_s))}"}.join('') + "'") if args
    url
  end

  def header 
    @template.render :partial=>'card/header', :locals=>{ :card=>card, :slot=>self }
  end

  def menu   
    if card.virtual?
      return %{<span class="card-menu faint">Virtual</span>\n}
    end
    menu = %{<span class="card-menu">\n}
    menu << %{<span class="card-menu-left">\n}
  	menu << link_to_menu_action('view')
  	menu << link_to_menu_action('changes')
  	menu << link_to_menu_action('options') 
  	menu << link_to_menu_action('related')
  	menu << "</span>"
    
  	menu << link_to_menu_action('edit') 
  	
    
    menu << "</span>"
  end

  def footer 
    render_partial 'card/footer' 
  end
            
  def footer_links
    cache_view(:footer) { 
      render_partial( 'card/footer_links' )   # this is ugly reusing this cache code
    }
  end     
  
  def option( args={}, &proc)
    args[:label] ||= args[:name]
    args[:editable]= true unless args.has_key?(:editable)
    self.options_need_save = true if args[:editable]
    concat %{<tr>
      <td class="inline label"><label for="#{args[:name]}">#{args[:label]}</label></td>
      <td class="inline field">
    }, proc.binding
    yield
    concat %{
      </td>
      <td class="help">#{args[:help]}</td>
      </tr>
    }, proc.binding
  end

  def option_header(title)
    %{<tr><td colspan="3" class="option-header"><h2>#{title}</h2></td></tr>}
  end

  def link_to_menu_action( to_action)
    menu_action = (%w{ show update }.member?(action) ? 'view' : action)
    content_tag( :li, link_to_action( to_action.capitalize, to_action, {} ),
      :class=> (menu_action==to_action ? 'current' : ''))
  end

  def link_to_action( text, to_action, remote_opts={}, html_opts={})
    link_to_remote text, {
      :url=>url_for("card/#{to_action}"),
      :update => id
    }.merge(remote_opts), html_opts
  end

  def button_to_action( text, to_action, remote_opts={}, html_opts={})
    if remote_opts.delete(:replace)
      r_opts =  { :url=>url_for("card/#{to_action}", :replace=>id ) }.merge(remote_opts)
    else
      r_opts =  { :url=>url_for("card/#{to_action}" ), :update => id }.merge(remote_opts)
    end
    button_to_remote( text, r_opts, html_opts )
  end

  def name_field(form,options={})
    form.text_field( :name, { :class=>'field card-name-field'}.merge(options))
  end


  def cardtype_field(form,options={})
    text = %{<span class="label"> type:</span>\n} 
    text << @template.select_tag('card[type]', cardtype_options_for_select(card.type), options) 
  end

  def update_cardtype_function(options={})
    fn = ['File','Image'].include?(card.type) ? 
            "Wagn.onSaveQueue['#{context}'].clear(); " :
            "Wagn.runQueue(Wagn.onSaveQueue['#{context}']); "      
    if @card.hard_template
      #options.delete(:with)
    end
    fn << remote_function( options )   
  end
     
  def js_content_element 
    @card.hard_template ? "" : ",getSlotElement(this,'form').elements['card[content]']" 
  end

  def content_field(form,options={})   
    self.form = form              
    @nested = options[:nested]
    pre_content =  (card and !card.new_record?) ? form.hidden_field(:current_revision_id, :class=>'current_revision_id') : ''
    editor_partial = (card.type=='Pointer' ? ((c=System.setting("#{card.name.tag_name}+*input")) ? c.gsub(/[\[\]]/,'') : 'list') : 'editor')
    pre_content + self.render_partial( card_partial(editor_partial), options ) + setup_autosave
  end                          
 
  def save_function 
    "if(ds=Wagn.draftSavers['#{context}']){ds.stop()}; if (Wagn.runQueue(Wagn.onSaveQueue['#{context}'])) { } else {return false}"
  end

  def cancel_function 
    "if(ds=Wagn.draftSavers['#{context}']){ds.stop()}; Wagn.runQueue(Wagn.onCancelQueue['#{context}']);"
  end


  def editor_hooks(hooks)
    # it seems as though code executed inline on ajax requests works fine
    # to initialize the editor, but when loading a full page it fails-- so
    # we run it in an onLoad queue.  the rest of this code we always run
    # inline-- at least until that causes problems.    
    
    #FIXME: this looks like it won't work for arbitraritly nested forms.  1-level only
    hook_context = @nested ? context.split('_')[0..-2].join('_') : context
    code = "" 
    if hooks[:setup]
      code << "Wagn.onLoadQueue.push(function(){\n" unless request.xhr?
      code << hooks[:setup]
      code << "});\n" unless request.xhr?
    end
    root.js_queue_initialized||={}
    unless root.js_queue_initialized.has_key?(hook_context) 
      #code << "warn('initializing #{hook_context} save & cancel queues');"
      code << "Wagn.onSaveQueue['#{hook_context}']=$A([]);\n"
      code << "Wagn.onCancelQueue['#{hook_context}']=$A([]);\n"
      root.js_queue_initialized[hook_context]=true
    end
    if hooks[:save]  
      code << "Wagn.onSaveQueue['#{hook_context}'].push(function(){\n"
      #code << "warn('running #{hook_context} save hook');"
      code << hooks[:save]
      code << "});\n"
      code << "warn('hook: fn(){ #{hooks[:save].gsub(/\'/,"|").gsub(/\n/,"; ")} }');"
      #code << "added to #{hook_context} save queue');"
    end
    if hooks[:cancel]
      code << "Wagn.onCancelQueue['#{hook_context}'].push(function(){\n"
      code << hooks[:cancel]
      code << "});\n"
    end
    javascript_tag code
  end                   
  
  def setup_autosave
    if @nested or skip_autosave 
      ""
    else
      javascript_tag "Wagn.setupAutosave('#{card.id}', '#{context}');\n"
    end
  end
          
  def half_captcha
    if captcha_required?
      key = card.new_record? ? "new" : card.key
      javascript_tag(%{loadScript("http://api.recaptcha.net/js/recaptcha_ajax.js")}) +
        recaptcha_tags( :ajax=>true, :display=>{:theme=>'white'}, :id=>key)
    end
  end
  
  def full_captcha
    if captcha_required?
      key = card.new_record? ? "new" : card.key          
        recaptcha_tags( :ajax=>true, :display=>{:theme=>'white'}, :id=>key ) +
          javascript_tag(   
            %{jQuery.getScript("http://api.recaptcha.net/js/recaptcha_ajax.js", function(){
              document.getElementById('dynamic_recaptcha-#{key}').innerHTML='<span class="faint">loading captcha</span>'; 
              Recaptcha.create('#{ENV['RECAPTCHA_PUBLIC_KEY']}', document.getElementById('dynamic_recaptcha-#{key}'),RecaptchaOptions);
            });
          })
    end
  end
end  