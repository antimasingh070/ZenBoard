# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2023  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class WelcomeController < ApplicationController
  self.main_menu = false

  skip_before_action :check_if_login_required, only: [:robots]

  def project_dashboard
    if params[:function_filter].present? && params[:category_filter].present?
      @projects = Project.select { |project| custom_field_value(project, "Project Category") == params[:category_filter] && custom_field_value(project, "User Function") == params[:function_filter] }
    elsif params[:function_filter].present?
      @projects = Project.select { |project| custom_field_value(project, "User Function") == params[:function_filter] }
    elsif params[:category_filter].present?
      @projects = Project.select { |project| custom_field_value(project, "Project Category") == params[:category_filter] }
    else
      @projects = Project.all
    end
  
    @project_status_text = {
      Project::STATUS_ACTIVE => 'Active',
      Project::STATUS_CLOSED => 'Closed',
      Project::STATUS_ARCHIVED => 'Archived',
      Project::STATUS_SCHEDULED_FOR_DELETION => 'Scheduled for Deletion'
    }
    @categories = @projects.map { |project| custom_field_value(project, "Project Category") }.uniq.compact
    @functions = @projects.map { |project| custom_field_value(project, "User Function") }.uniq.compact
  end

  def custom_field_value(project, field_name)
    custom_field = CustomField.find_by(name: field_name)
    custom_value = CustomValue.find_by(customized_type: "Project", customized_id: project&.id, custom_field_id: custom_field&.id)
    custom_field_enumeration = CustomFieldEnumeration.find_by(id: custom_value&.value&.to_i)
    custom_field_enumeration&.name
  end

  def index
    @news = News.latest User.current
  end

  def robots
    @projects = Project.visible(User.anonymous) unless Setting.login_required?
    render :layout => false, :content_type => 'text/plain'
  end
end
