# frozen_string_literal: true

module Api
  module V1
    class UsersController < ApplicationController
      skip_before_action :verify_authenticity_token  # Skip CSRF protection for API

      def create
        permitted_params = user_params

        # If you need to merge in additional parameters like email (params[:user][:mail])
        if params[:user].key?(:mail)
          permitted_params[:mail] = params[:user][:mail]
        end

        @user = User.new(permitted_params)
        if @user.save
          api_key = @user.api_key # or however the API key is generated/retrieved

          # Include the API key in the JSON response
          render json: @user.as_json.merge(api_key: api_key), status: :created
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def show
        @user = User.find(params[:id])
        render json: @user
      end

      def update
        @user = User.find(params[:id])

        if @user.update(user_params)
          render json: @user
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @user = User.find(params[:id])
        @user.destroy
        head :no_content
      end

      private

      def user_params
        params.require(:user).permit(:login, :firstname, :lastname, :password, :admin, :status, :language, :mail_notification, :must_change_passwd, :mail)
      end
    end
  end
end
