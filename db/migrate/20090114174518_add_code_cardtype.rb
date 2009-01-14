require_dependency 'db/migration_helper'

class AddCodeCardtype < ActiveRecord::Migration
	include MigrationHelper

  def self.up 
  	add_cardtype "Code"
  end

  def self.down
  end
end
