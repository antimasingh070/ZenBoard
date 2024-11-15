# app/controllers/remarks_controller.rb
class RemarksController < ApplicationController
    before_action :set_meeting
    before_action :set_mom
    before_action :set_point
  
    def create
      @remark = @point.remarks.build(remark_params)
      @remark.author = User.current  # Assuming you have a current_user method
  
      if @remark.save
        redirect_to business_requirement_meeting_path(@mom.meeting.business_requirement, @mom.meeting), notice: 'Successfully Updated.'
      else
        redirect_to business_requirement_meeting_path(@mom.meeting.business_requirement, @mom.meeting), alert: 'Failed to add remark.'
      end      
    end
  
    private
  
    def set_meeting
      @meeting = Meeting.find(params[:meeting_id])
    end
  
    def set_mom
      @mom = @meeting.mom
    end

    def set_point
      @point = Point.find(params[:point_id])
    end
  
    def remark_params
      params.require(:remark).permit(:content)
    end
end
  