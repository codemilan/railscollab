=begin
RailsCollab
-----------

=end

class TimeController < ApplicationController

  layout 'project_website'
  
  verify :method => :post,
  		 :only => :delete,
  		 :add_flash => { :flash_error => "Invalid request" },
         :redirect_to => { :controller => 'project' }

  before_filter :login_required
  before_filter :process_session
  before_filter :obtain_time, :except => [:index, :add]
  after_filter  :user_track, :only => [:index, :view, :by_task] 
  
  def index
    @project = @active_project

    current_page = params[:page].to_i
    current_page = 0 unless current_page > 0
    
    time_conditions = @logged_user.member_of_owner? ? "project_id = ?" : "project_id = ? AND is_private = false"
    sort_type = params[:orderBy]
    sort_type = 'created_on' unless ['done_date', 'hours'].include?(params[:orderBy])
    sort_order = 'DESC'
    
    @times = ProjectTime.find(:all, :conditions => [time_conditions, @project.id], :page => {:size => AppConfig.times_per_page, :current => current_page}, :order => "#{sort_type} #{sort_order}")
    @pagination = []
    @times.page_count.times {|page| @pagination << page+1}
    
    @content_for_sidebar = 'index_sidebar'
  end
  
  def by_task
  end
  
  def view
    begin
      @time = ProjectTime.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:flash_error] = "Invalid time record"
      redirect_back_or_default :controller => 'time'
      return
    end
    
    if not @time.can_be_seen_by(@logged_user)
      flash[:flash_error] = "Insufficient permissions"
      redirect_back_or_default :controller => 'time'
      return
    end
  end
  
  def add
    @time = ProjectTime.new
    
    if not ProjectTime.can_be_created_by(@logged_user, @active_project)
      flash[:flash_error] = "Insufficient permissions"
      redirect_back_or_default :controller => 'time'
      return
    end
    
    @open_task_lists = @active_project.open_task_lists
    
    case request.method
      when :post
        time_attribs = params[:time]
        
        @time.update_attributes(time_attribs)
        
        @time.project = @active_project
        @time.created_by = @logged_user
        
        if @logged_user.member_of_owner?
        	@time.is_private = time_attribs[:is_private]
        	@time.is_billable = time_attribs[:is_billable]
        end
        
        if @time.save
          ApplicationLog::new_log(@time, @logged_user, :add, @time.is_private)
          flash[:flash_success] = "Successfully added time record"
          redirect_back_or_default :controller => 'time'
        end
    end
  end
  
  def edit
    begin
      @time = ProjectTime.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:flash_error] = "Invalid time record"
      redirect_back_or_default :controller => 'time'
      return
    end
    
    if not @time.can_be_edited_by(@logged_user)
      flash[:flash_error] = "Insufficient permissions"
      redirect_back_or_default :controller => 'time'
      return
    end
    
    @open_task_lists = @active_project.open_task_lists
    
    case request.method
      when :post
        time_attribs = params[:time]
        
        @time.update_attributes(time_attribs)
        @time.created_by = @logged_user
        
        if @logged_user.member_of_owner?
        	@time.is_private = time_attribs[:is_private]
        	@time.is_billable = time_attribs[:is_billable]
        end
        
        if @time.save
          ApplicationLog::new_log(@time, @logged_user, :edit, @time.is_private)
          flash[:flash_success] = "Successfully edited time record"
          redirect_back_or_default :controller => 'time', :id => @time.id
        end
    end
  end
  
  def delete
    if not @time.can_be_deleted_by(@logged_user)
      flash[:flash_error] = "Insufficient permissions"
      redirect_back_or_default :controller => 'time'
      return
    end
    
    ApplicationLog::new_log(@time, @logged_user, :delete, @time.is_private)
    @time.destroy
    
    flash[:flash_success] = "Successfully deleted time record"
    redirect_back_or_default :controller => 'time'
  end

private

  def obtain_time
    begin
      @time = ProjectTime.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:flash_error] = "Invalid time record"
      redirect_back_or_default :controller => 'time'
      return false
    end
    
    return true
  end
  
end