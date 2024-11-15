# app/controllers/points_controller.rb
class PointsController < ApplicationController
    before_action :set_mom
    before_action :set_point, only: [:edit, :update, :destroy, :accept, :reject]
  
    def new
      @point = @mom.points.build
      @business_requirement = BusinessRequirement.find_by(id: params[:business_requirement_id])
      @br_stakeholders = @business_requirement.br_stakeholders
    end
  
    def create
      @point = @mom.points.build(point_params)
      @business_requirement = BusinessRequirement.find_by(id: params[:business_requirement_id])
      @br_stakeholders = @business_requirement.br_stakeholders
      if @point.save
        redirect_to business_requirement_meeting_path(@mom.meeting.business_requirement_id, @mom.meeting), notice: 'Successfully Added.'
      else
        render :new
      end
    end
  
    def edit
      @business_requirement = BusinessRequirement.find_by(id: params[:business_requirement_id])
      @br_stakeholders = @business_requirement.br_stakeholders
    end
  
    def update
      @business_requirement = BusinessRequirement.find_by(id: params[:business_requirement_id])
      @br_stakeholders = @business_requirement.br_stakeholders
      @meeting = @mom.meeting
      if @point.update(point_params)
        redirect_to business_requirement_meeting_path(@mom.meeting.business_requirement, @mom.meeting), notice: 'Successfully updated.'
      else
        render :edit
      end
    end
  
    def destroy
      @point.destroy
      redirect_to business_requirement_meeting_path(@mom.meeting.business_requirement, @mom.meeting), notice: 'Successfully deleted.'
    end
  
    def accept
      @point.update(status: 1)
      redirect_to business_requirement_meeting_path(@mom.meeting.business_requirement, @mom.meeting), notice: 'Successfully accepted.'

    end
  
    def reject
      @point.update(status: 2)
      redirect_to business_requirement_meeting_path(@mom.meeting.business_requirement, @mom.meeting), notice: 'Point was successfully accepted.'
    end
  
    private

    def set_mom
      @meeting = Meeting.find(params[:meeting_id])
      @mom = @meeting.mom
    end
  
    def set_point
      @point = @mom.points.find(params[:id])
    end
  
    def point_params
      params.require(:point).permit(:description, :status, :owner, :timeline)
    end
end
  