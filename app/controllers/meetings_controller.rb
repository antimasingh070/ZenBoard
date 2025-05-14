# frozen_string_literal: true

# app/controllers/meetings_controller.rb
class MeetingsController < ApplicationController
  before_action :set_business_requirement, only: [:new, :create, :show, :edit, :update, :destroy, :send_meeting_invitation]
  before_action :set_meeting, only: [:show, :edit, :update, :destroy, :send_meeting_invitation]

  def send_meeting_invitation
    @business_requirement = BusinessRequirement.find(params[:business_requirement_id])
    @meeting =  Meeting.find(params[:id])
    if @meeting.meeting_attendees.any?
      # Send email to all stakeholders in a single email
      meeting_attendees = @meeting.meeting_attendees
      Mailer.deliver_meeting_invitation(User.current, @meeting)
      redirect_to edit_business_requirement_meeting_path(@business_requirement, @meeting), notice: 'Email sent successfully to all attendess.'
    else
      redirect_to edit_business_requirement_meeting_path(@business_requirement, @meeting), alert: 'Cannot send email: No attendess are associated with this meeting.'
    end
  end

  def new
    @meeting = @business_requirement.meetings.build
    @meeting.meeting_attendees.build
    @function_name = fetch_custom_field_names('Function')
  end

  def create
    @meeting = @business_requirement.meetings.build(meeting_params)
    @function_name = fetch_custom_field_names('Function')
    if @meeting.save
      @mom = Mom.find_or_create_by(meeting_id: @meeting.id)
      redirect_to edit_business_requirement_meeting_path(@business_requirement, @meeting), notice: 'Meeting was successfully created. Please add attendee'
    else
      render :new
    end
  end

  def edit
    @function_name = fetch_custom_field_names('Function')
    @meeting = @business_requirement.meetings.find(params[:id])
  end

  def show
    @meeting = @business_requirement.meetings.find(params[:id])
    @function_name = fetch_custom_field_names('Function')
    @br_stakeholders = @business_requirement.br_stakeholders
    @mom = @meeting.mom || @meeting.build_mom
    @points = @mom&.points&.where&.not(id: nil)
    @point = @mom.points.build if @mom.points.empty?
  end

  def update
    if @meeting.update(meeting_params)
      @mom = Mom.find_or_create_by(meeting_id: @meeting.id)
      redirect_to business_requirement_meeting_path(@business_requirement, @meeting), notice: 'Meeting was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @meeting.destroy
    redirect_to business_requirement_path(@business_requirement), notice: 'Meeting was successfully deleted.'
  end

  private

  def fetch_custom_field_names(name)
    custom_field = CustomField.find_by(name: name)
    CustomFieldEnumeration.where(custom_field_id: custom_field.id).pluck(:name) if custom_field
  end

  def set_business_requirement
    @business_requirement = BusinessRequirement.find(params[:business_requirement_id])
  end

  def set_meeting
    @meeting = @business_requirement.meetings.find(params[:id])
  end

  def meeting_params
    params.require(:meeting).permit(:title, :scheduled_at, :status, :function_name, :note,
      meeting_attendees_attributes: [:id, :user_id, :_destroy])
  end
end
