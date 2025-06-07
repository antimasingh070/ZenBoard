class WorkAllocationsController < ApplicationController
  protect_from_forgery with: :null_session
  skip_before_action :verify_authenticity_token

  def create
    member = Member.find_by(user_id: params[:user_id], project_id: params[:project_id])
    unless member
      member = Member.create(user_id: params[:user_id], project_id: params[:project_id])
    end

    if member.update(work_allocation: params[:work_allocation])
      render json: { success: true }
    else
      render json: { success: false, errors: member.errors.full_messages }
    end
  end

  def update
    member = Member.find_by(user_id: params[:user_id], project_id: params[:project_id])
    if member&.update(work_allocation: params[:work_allocation])
      render json: { success: true }
    else
      render json: { success: false, message: 'Update failed' }
    end
  end

  def destroy
    member = Member.find_by(user_id: params[:user_id], project_id: params[:project_id])
    if member&.update(work_allocation: nil)
      render json: { success: true }
    else
      render json: { success: false, message: 'Delete failed' }
    end
  end
end
