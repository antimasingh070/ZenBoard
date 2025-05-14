# frozen_string_literal: true

class BrStakeholdersController < ApplicationController
  before_action :set_business_requirement, only: [:new, :create, :edit, :update, :destroy]
  before_action :set_br_stakeholder, only: [:destroy, :update, :edit]

  def new
    @br_stakeholder = @business_requirement.br_stakeholders.build
  end

  def create
    @br_stakeholder = @business_requirement.br_stakeholders.build(br_stakeholder_params)
    if @br_stakeholder.save
      redirect_to @business_requirement, notice: 'Stakeholder was successfully added.'
    else
      flash[:alert] = @br_stakeholder.errors.full_messages.join(', ')
      render :new
    end
  end

  def edit
    @br_stakeholder = @business_requirement.br_stakeholders.find(params[:id])
  end

  def update
    @br_stakeholder = @business_requirement.br_stakeholders.find(params[:id])
    if @br_stakeholder.update(br_stakeholder_params)
      redirect_to edit_br_path(@business_requirement), notice: 'Stackholder was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @br_stakeholder.destroy
    redirect_to edit_business_requirement_path(@business_requirement), notice: 'Stackholder was successfully removed.'
  end

  private

  def set_business_requirement
    @business_requirement = BusinessRequirement.find(params[:business_requirement_id])
  end

  def set_br_stakeholder
    @br_stakeholder = @business_requirement.br_stakeholders.find(params[:id])
  end

  def br_stakeholder_params
    params.require(:br_stakeholder).permit(:user_id, :role_id)
  end
end
