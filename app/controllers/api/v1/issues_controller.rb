# frozen_string_literal: true

module Api
  module V1
    class IssuesController < ApplicationController
      before_action :verify_authenticity_token, only: [:create]

      def index
        @issues = Issue.all
        render json: @issues
      end

      def show
        @issue = Issue.find(params[:id])
        render json: @issue
      end

      def create
        @issue = Issue.new(issue_params.to_h.merge(author_id: current_user.id))

        if @issue.save
          render json: @issue, status: :created
        else
          render json: { errors: @issue.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # Implement other CRUD actions and custom actions as needed

      private

      def issue_params
        params.require(:issue).permit(:subject, :description, :status_id, :priority_id, :project_id, :tracker_id, :assigned_to_id, :author_id)
      end
    end
  end
end
