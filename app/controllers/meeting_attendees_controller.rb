class MeetingAttendeesController < ApplicationController
    before_action :set_br, only: [:new, :create, :edit, :update, :destroy]
    before_action :set_meeting, only: [:new, :create, :edit, :update, :destroy]
    before_action :set_meeting_attendee, only: [:destroy, :update, :edit]

    def new
        @meeting_attendee = @meeting.meeting_attendees.build
    end

    def create
        @meeting_attendee = @meeting.meeting_attendees.build(meeting_attendee_params)
        if @meeting_attendee.save
          redirect_to @meeting, notice: 'Attendee was successfully added.'
        else
          flash[:alert] = @meeting_attendee.errors.full_messages.join(', ')
          render :new
        end
    end
      
  
    def edit
      @meeting_attendee = @meeting.meeting_attendees.find(params[:id])
    end
  
    def update
      @meeting_attendee = @meeting.meeting_attendees.find(params[:id])
      if @meeting_attendee.update(meeting_attendee_params)
        redirect_to edit_br_meeting_path(@meeting), notice: 'Attendee was successfully updated.'
      else
        render :edit
      end
    end
  
    def destroy
      @meeting_attendee.destroy
      redirect_to edit_br_meeting_path(@meeting), notice: 'Attendee was successfully removed.'
    end
  
    private

    def set_br
        @business_requirement = BusinessRequirement.find(params[:business_requirement_id])
    end

    def set_meeting
        @meeting = Meeting.find(params[:meeting_id])
    end
  
    def set_meeting_attendee
      @meeting_attendee = @meeting.meeting_attendees.find(params[:id])
    end
  
    def meeting_attendee_params
      params.require(:meeting_attendee).permit(:user_id, :role_id)
    end
end
  