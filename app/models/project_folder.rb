=begin
RailsCollab
-----------

=end

class ProjectFolder < ActiveRecord::Base
	include ActionController::UrlWriter
	
	belongs_to :project
	
	has_many :project_files, :foreign_key => 'folder_id'
	
	def object_name
		self.name
	end
	
	def object_url
		url_for :only_path => true, :controller => 'files', :action => 'browse_folder', :id => self.id, :active_project => self.project_id
	end
		
	# Core Permissions
	
	def self.can_be_created_by(user, project)
	  user.has_permission(project, :can_manage_files)
	end
	
	def can_be_edited_by(user)
	  user.has_permission(project, :can_manage_files)
	end
	
	def can_be_deleted_by(user)
	  user.has_permission(project, :can_manage_files)
	end
	
	def can_be_seen_by(user)
	 self.project.has_member(user)
	end
	
	# Specific Permissions

    def can_be_managed_by(user)
	 user.has_permission(project, :can_manage_files)
    end
    
    # Helpers
    
	def self.select_list(project)
	   [['None', 0]] + ProjectFolder.find(:all, :conditions => "project_id = #{project.id}", :select => 'id, name').collect do |folder|
	      [folder.name, folder.id]
	   end
	end
	
	# Accesibility
	
	attr_accessible :name
	
	# Validation
	
	validates_presence_of :name
	validates_uniqueness_of :name
end