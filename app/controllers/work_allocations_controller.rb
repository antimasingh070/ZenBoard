# frozen_string_literal: true

class WorkAllocationsController < ApplicationController
  before_action :find_member, only: [:update, :destroy]

  def update
    if @member.update(work_allocation: params[:work_allocation])
      redirect_to "http://localhost:3000/projects/#{@member.project.identifier}/settings/members"
    else
      redirect_to "http://localhost:3000/projects/#{@member.project.identifier}/settings/members"
    end
  end

  def destroy
    @member.update(work_allocation: nil)
    respond_to do |format|
      format.js   # Renders destroy.js.erb
      format.json { render json: { status: 'success', message: 'Member deleted' } }
    end
  end

  private

  def find_member
    @member = Member.find(params[:id])
  end

  def work_allocation_params
    params.require(:member).permit(:work_allocation)
  end
end
