=begin
RailsCollab
-----------

=end

class ImValue < ActiveRecord::Base
	set_table_name 'user_im_values'
	
	belongs_to :user
	belongs_to :im_type
end