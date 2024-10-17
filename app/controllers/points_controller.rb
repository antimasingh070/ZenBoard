# app/controllers/points_controller.rb
class PointsController < ApplicationController
    before_action :set_mom
    before_action :set_point, only: [:edit, :update, :destroy, :accept, :reject]
  
    def new
      @point = @mom.points.build
    end
  
    def create
      @point = @mom.points.build(point_params)
      if @point.save
        redirect_to business_requirement_meeting_path(@mom.meeting.business_requirement_id, @mom.meeting), notice: 'Point was successfully created.'
      else
        render :new
      end
    end
  
    def edit
    end
  
    def update
      if @point.update(point_params)
        redirect_to @mom.meeting, notice: 'Point was successfully updated.'
      else
        render :edit
      end
    end
  
    def destroy
      @point.destroy
      redirect_to @mom.meeting, notice: 'Point was successfully destroyed.'
    end
  
    def accept
      @point.update(status: 1)
      redirect_to business_requirement_meeting_path(@mom.meeting.business_requirement, @mom.meeting), notice: 'Point was successfully accepted.'

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
      params.require(:point).permit(:description, :status)
    end
end
  