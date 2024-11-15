# app/controllers/remarks_controller.rb
class RemarksController < ApplicationController
    before_action :set_meeting
    before_action :set_mom
    before_action :set_point
    before_action :set_remark, only: [:update, :destroy]
    
    def create
      @remark = @point.remarks.build(remark_params)
      @remark.author = User.current  # Assuming you have a current_user method
  
      if @remark.save
        redirect_to business_requirement_meeting_path(@mom.meeting.business_requirement, @mom.meeting), notice: 'Successfully Updated.'
      else
        redirect_to business_requirement_meeting_path(@mom.meeting.business_requirement, @mom.meeting), alert: 'Failed to add remark.'
      end      
    end
  
    def update
      if @remark.update(remark_params)
        redirect_to request.referrer, notice: 'Successfully updated.'
      else
        redirect_to request.referrer, alert: 'Failed to update remark.'
      end
    end
  
    def destroy
      @remark.destroy
      redirect_to request.referrer, notice: 'Successfully deleted.'
    end

    private
  
    def set_remark
      @remark = Remark.find(params[:id])
    end

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
  