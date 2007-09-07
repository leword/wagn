class CardnameController < ApplicationController
  helper :wagn, :card 
  cache_sweeper :card_sweeper
  before_filter :load_card, :edit_ok    
  
  def update  
    if @card.update_attributes params[:card]
      render :action=>'view'
    elsif @card.errors.on(:confirmation_required)
      @action = 'confirm'
      render :action=>'edit', :status=>422
    else
      render :action=>'edit', :status=>422
    end
  end

=begin
  def confirm
    @action = 'confirm'
    if params[:card] and name=params[:card][:name]
      @card.name = name
    end
    render :action=>'edit'
  end
=end

end