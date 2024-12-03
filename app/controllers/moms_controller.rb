# app/controllers/moms_controller.rb
class MomsController < ApplicationController
  before_action :set_meeting

    
  def send_mom_email
    
    @meeting = Meeting.find(params[:meeting_id])
    @mom = @meeting.mom
    @business_requirement = @meeting.business_requirement
    @points = @mom.points

    if  (@meeting.meeting_attendees.present? || @points.pluck(:owner).present?)  && @points.present?
      # Send email to all stakeholders in a single email
      attendees = @meeting.meeting_attendees
      Mailer.deliver_send_mom(User.current, attendees.pluck(:user_id), @points.pluck(:id), @meeting.id)
      redirect_to business_requirement_meeting_path(@business_requirement, @meeting), notice: 'Mail Sent.'
    else
      redirect_to business_requirement_meeting_path(@business_requirement, @meeting), alert: 'Cannot send email: there is not mom.'
    end
  end

  def show
    @meeting = Meeting.find(params[:meeting_id])
    @business_requirement = @meeting.business_requirement # Ensure that the business requirement is set here
  end

  
  def new
    @mom = @meeting.build_mom  # Use build_mom for has_one association
    @function_name = fetch_custom_field_names('Function')
  end

  def create
    @business_requirement = BusinessRequirement.find(params[:business_requirement_id])
    @meeting = @business_requirement.meetings.find(params[:meeting_id])
    @mom = @meeting.build_mom(mom_params)
    if @mom.save
      
      redirect_to business_requirement_meeting_path(@business_requirement, @meeting), notice: 'Successfully created.'
    else
      render :new
    end
  end

  def edit
    @business_requirement = BusinessRequirement.find(params[:business_requirement_id])
    @meeting = @business_requirement.meetings.find(params[:meeting_id])
    @mom = @meeting.mom
  end

  def update
    @business_requirement = BusinessRequirement.find(params[:business_requirement_id])
    @meeting = @business_requirement.meetings.find(params[:meeting_id])
    @mom = @meeting.mom
    if @mom.update(mom_params)
      redirect_to business_requirement_meeting_path(@business_requirement, @meeting), notice: 'Successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @business_requirement = BusinessRequirement.find(params[:business_requirement_id])
    @meeting = @business_requirement.meetings.find(params[:meeting_id])
    @mom = @meeting.mom
    @mom.destroy
    redirect_to business_requirement_meeting_path(@business_requirement, @meeting), notice: 'MOM was successfully deleted.'
  end

  private

  def set_meeting
    @meeting = Meeting.find(params[:meeting_id])
  end

  def mom_params
    params.require(:mom).permit(:function_name, :summary, :status, :target_date)
  end
end
