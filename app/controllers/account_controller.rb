=begin
RailsCollab
-----------

=end

class AccountController < ApplicationController

  verify :method => :post,
  		 :only => [ :delete_avatar ],
  		 :add_flash => { :flash_error => "Invalid request" },
         :redirect_to => { :controller => 'account' }
  
  before_filter :login_required
  before_filter :process_session
  before_filter :obtain_user, :except => [:index, :avatar]
  after_filter :user_track, :only => [:index]

  # Caching
  caches_page :avatar
  cache_sweeper :account_sweeper, :only => [ :edit_profile, :edit_avatar, :delete_avatar ]
  
  def index
  	@user = @logged_user
  end
  
  def edit_profile
    if not @user.profile_can_be_updated_by(@logged_user)
      redirect_back_or_default :controller => 'dashboard'
      return
    end
    
    case request.method
      when :post
        user_params = params[:user]
        
        # Process IM Values
        all_im_values = params[:im_values]
        all_im_values.reject! do |key, value|
        	value[:value].strip.length == 0
        end

        if params[:default_im_value].nil?
        	default_value = "-1"
        else
        	default_value = params[:default_im_value]
        end
        
        real_im_values = all_im_values.collect do |type_id,value|
        	real_im_value = value[:value]
        	ImValue.new(:im_type_id => type_id.to_i, :user_id => @user.id, :value => real_im_value, :is_default => (default_value == type_id))
        end
        
        # Process extra parameters
        
        if @logged_user.is_admin?
        	@user.username = user_params[:username]
        	if @logged_user.member_of_owner?
        		@user.company_id = user_params[:company_id]
        		@user.is_admin = user_params[:is_admin]
        		@user.auto_assign = user_params[:auto_assign]
        	end
        end
        
        if user_params[:identity_url]
        	@user.identity_url = user_params[:identity_url]
        end
        
        # Process core parameters
        
        @user.update_attributes(user_params)
        
        # Send it off
        
        if @user.save
          # Re-create ImValues for user
          ActiveRecord::Base.connection.execute("DELETE FROM user_im_values WHERE user_id = #{@user.id}")
          real_im_values.each do |im_value|
            im_value.save
          end
          flash[:flash_success] = "Successfully updated profile"
          redirect_back_or_default :controller => 'dashboard'
        end
    end
    
  end
  
  def edit_password
    case request.method
      when :post
        if @user.nil?
          redirect_back_or_default :controller => 'dashboard'
          return
        end
        
        if not @user.profile_can_be_updated_by(@logged_user)
          @user.errors.add(:logged_user, "Has insufficient permissions")
          return
        end
        
        @password_data = params[:user]
        if not @logged_user.is_admin?
          if not @password_data[:old_password]
            @user.errors.add(:old_password, "Required")
            return
          end
            
          if not @user.valid_password(@password_data[:old_password])
            @user.errors.add(:old_password, "Is incorrect")
            return
          end
        end
            
        if not @password_data[:password]
          @user.errors.add(:password, "New password required")
          return
        end
          
        if not @password_data[:password] == @password_data[:password_confirmation]
          @user.errors.add(:password_confirmation, "Does not match")
          return
        end
    
        @user.password = @password_data[:password]
        @user.save
        
        flash[:flash_success] = "Password changed"
        redirect_back_or_default :controller => 'dashboard'
        return
    end
  end
  
  def update_permissions
    if !@user.permissions_can_be_updated_by(@logged_user)
      flash[:flash_error] = "Insufficient permissions"
      redirect_back_or_default :controller => 'dashboard'
      return
    end
    
    @projects = @user.company.projects
    @permissions = ProjectUser.permission_names()
    
    case request.method
      when :post
          user_project = params[:user_project]
          user_project ||= []
          
          # Grab the list of project id's specified
          project_list = user_project.select do |project_id|
          	begin
          		project = Project.find(project_id)
          		project.can_be_managed_by(@logged_user)
    		rescue ActiveRecord::RecordNotFound
    			false
          	end
          end
          
          # Associate project permissions with user
          project_permission = params[:project_permission]
          project_list.each do |project_id|
          	permission_list = project_permission.nil? ? nil : project_permission[project_id]
          	
          	# Find permission list
          	project_user = ProjectUser.find(:first, :conditions => ['user_id = ? AND project_id = ?', @user.id, project_id])
          	if project_user.nil?
    			Project.find(project_id).users << @user
          	end
          	
          	# Reset and update permissions
          	if permission_list.nil?
          		ProjectUser.update_all(ProjectUser.update_str, ['user_id = ? AND project_id = ?', @user.id, project_id])
          	else
          		ProjectUser.update_all(ProjectUser.update_str(permission_list), ['user_id = ? AND project_id = ?', @user.id, project_id])
          	end
          end
          
          # Delete all permissions that aren't in the project list
          delete_list = @projects.collect do |project|
          	if !project_list.include?(project.id.to_s)
          		project.id
          	else
          		nil
          	end
          end.compact
          
          if delete_list.length > 0
          	ProjectUser.delete_all("user_id = #{@user.id} AND project_id IN (#{delete_list.join(', ')})")
          end
          
          #ApplicationLog.new_log(@project, @logged_user, :edit, true)
            
          flash[:flash_success] = "Successfully updated permissions"
          redirect_to :controller => 'account', :action => 'update_permissions', :id => @user.id
    end
  end
  
  def edit_avatar
  	if not @user.profile_can_be_updated_by(@logged_user)
      flash[:flash_error] = "Insufficient permissions"
      redirect_back_or_default :controller => 'dashboard'
      return
  	end

    case request.method
      when :post
          user_attribs = params[:user]
          
          new_avatar = user_attribs[:avatar]
          if new_avatar.nil?
          	@user.errors.add(:avatar, 'Required')
          end
          
          @user.avatar = new_avatar
          
          if @user.errors.empty?
	          if @user.save
	          	flash[:flash_success] = "Successfully updated avatar"
	          else
	          	flash[:flash_error] = "Error uploading avatar"
	          end
	          
	          redirect_to :controller => 'account', :action => 'edit_avatar', :id => @user.id
          end
    end    
  end
  
  def delete_avatar    
  	if not @user.profile_can_be_updated_by(@logged_user)
      flash[:flash_error] = "Insufficient permissions"
      redirect_back_or_default :controller => 'dashboard'
      return
  	end
    
    @user.avatar = nil
    @user.save
    
    flash[:flash_success] = "Successfully deleted avatar"
    redirect_to :controller => 'account', :action => 'index'
  end
  
  def avatar
    begin
      user = User.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render :text => 'Not found', :status => 404
      return
    end
    
  	# Get avatar data
  	data = FileRepo.get_data(user.avatar_file)
  	
  	if data.empty?
  		render :text => 'Not found', :status => 404
  		return
  	end
  	
  	send_data data, :type => 'image/png', :disposition => 'inline'
  end

private

  def obtain_user
    begin
      @user = User.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:flash_error] = "Invalid user"
      redirect_back_or_default :controller => 'dashboard'
      return false
    end
    
    return true
  end
  
end