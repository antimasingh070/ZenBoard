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
  # STATUS_ACTIVE     = 1
  # STATUS_CLOSED     = 5
  # STATUS_ARCHIVED   = 9
  # STATUS_SCHEDULED_FOR_DELETION = 10
  # STATUS_HOLD = 11
  # STATUS_CANCELLED = 12


  def date_value(project, field_name)
    custom_field = CustomField.find_by(name: field_name)
    custom_value = CustomValue.find_by(customized_type: "Project", customized_id: project&.id, custom_field_id: custom_field&.id)
    date_string = custom_value&.value
end

  def it_project_dashboard 

    @project_status_text = {
      Project::STATUS_ACTIVE => 'Active',
      Project::STATUS_CLOSED => 'Closed',
      Project::STATUS_ARCHIVED => 'Archived',
      Project::STATUS_SCHEDULED_FOR_DELETION => 'Scheduled for Deletion',
      Project::STATUS_HOLD => "Hold",
      Project::STATUS_CANCELLED => "Cancelled"
    }

    current_user_id = User.current.id
    # Go Live date
    # @projects = Project.where(parent_id: nil)
    @projects = Project.where(parent_id: nil)
    .joins("LEFT JOIN custom_values ON custom_values.customized_id = projects.id AND custom_values.customized_type = 'Project'")
    .joins("LEFT JOIN custom_fields ON custom_fields.id = custom_values.custom_field_id")
    .where("custom_fields.name = ?", 'Planned Project Go Live Date')
    .order("custom_values.value DESC")
    custom_field = CustomField.find_by(name: "Is It Project")
    customized_ids = CustomValue.where(custom_field_id: custom_field.id, value: "1").pluck(:customized_id)

    @projects = @projects.where(id: customized_ids)
    @projects = @projects.where("custom_field_value(project, 'Project Category') = ?", params[:category_filter]) if params[:category_filter].present?
    @projects = @projects.where("custom_field_value(project, 'User Function') = ?", params[:function_filter]) if params[:function_filter].present?
    @projects = @projects.where(status: params[:status_filter].to_i) if params[:status_filter].present?
    @projects = @projects.where("project.name = ?", params[:name_filter]) if params[:name_filter].present?
    @projects = @projects.select { |project| member_names(project, 'Project Manager').include?(params[:manager_filter]) } if params[:manager_filter].present?

    if params[:start_date_from].present? && params[:start_date_to].present?
      start_date_range = Date.parse(params[:start_date_from])..Date.parse(params[:start_date_to])
      @projects = @projects.select { |project| start_date_range.cover?(Date.parse(date_value(project, 'Scheduled Start Date'))) }
    end

    if params[:end_date_from].present? && params[:end_date_to].present?
      end_date_range = Date.parse(params[:end_date_from])..Date.parse(params[:end_date_to])
      @projects = @projects.select { |project| end_date_range.cover?(Date.parse(date_value(project, 'Scheduled End Date'))) }
    end

    @projects = @projects.select { |project| project.members.exists?(user_id: current_user_id) }
    @categories = @projects.map { |project| custom_field_value(project, 'Portfolio Category') }.compact.uniq
    @functions = @projects.map { |project| custom_field_value(project, 'User Function') }.compact.uniq
    @statuses = @projects.map { |project| @project_status_text[project.status] }.compact.uniq
    @managers = @projects.flat_map { |project| member_names(project, 'Project Manager') }.compact.uniq

    @names = @projects.map(&:name).compact.uniq
    # Projects going live next week
    start_date_next_week = Date.today.next_week.beginning_of_week
    end_date_next_week = Date.today.next_week.end_of_week
    @next_week_go_live_projects = @projects.select { |project| 
   begin
      go_live_date = Date.parse(date_value(project, 'Planned Project Go Live Date'))
      go_live_date >= start_date_next_week && go_live_date <= end_date_next_week
    rescue ArgumentError
      false
    end
    }

    # Remove this line if you don't want to limit to the first 3 projects
    @next_week_go_live_projects = @next_week_go_live_projects[0..2]

 
  end

  def non_it_project_dashboard
    begin
    @project_status_text = {
      Project::STATUS_ACTIVE => 'Active',
      Project::STATUS_CLOSED => 'Closed',
      Project::STATUS_ARCHIVED => 'Archived',
      Project::STATUS_SCHEDULED_FOR_DELETION => 'Scheduled for Deletion',
      Project::STATUS_HOLD => "Hold",
      Project::STATUS_CANCELLED => "Cancelled"
    }

    current_user_id = User.current.id
    # Go Live date
    # @projects = Project.where(parent_id: nil)
    @projects = Project.where(parent_id: nil)
    .joins("LEFT JOIN custom_values ON custom_values.customized_id = projects.id AND custom_values.customized_type = 'Project'")
    .joins("LEFT JOIN custom_fields ON custom_fields.id = custom_values.custom_field_id")
    .where("custom_fields.name = ?", 'Planned Project Go Live Date')
    .order("custom_values.value DESC")
    custom_field = CustomField.find_by(name: "Is IT Project")
    customized_ids = CustomValue.where(custom_field_id: custom_field.id, value: "0").pluck(:customized_id)
    @projects = @projects.where(id: customized_ids)
    @projects = @projects.where("custom_field_value(project, 'Project Category') = ?", params[:category_filter]) if params[:category_filter].present?
    @projects = @projects.where("custom_field_value(project, 'User Function') = ?", params[:function_filter]) if params[:function_filter].present?
    @projects = @projects.where("custom_field_value(project, 'Template') = ?", params[:template_filter]) if params[:template_filter].present?
    @projects = @projects.where(status: params[:status_filter].to_i) if params[:status_filter].present?
    @projects = @projects.where("project.name = ?", params[:name_filter]) if params[:name_filter].present?
    @projects = @projects.select { |project| member_names(project, 'Project Manager').include?(params[:manager_filter]) } if params[:manager_filter].present?

    if params[:start_date_from].present? && params[:start_date_to].present?
      start_date_range = Date.parse(params[:start_date_from])..Date.parse(params[:start_date_to])
      @projects = @projects.select { |project| start_date_range.cover?(Date.parse(date_value(project, 'Scheduled Start Date'))) }
    end

    if params[:end_date_from].present? && params[:end_date_to].present?
      end_date_range = Date.parse(params[:end_date_from])..Date.parse(params[:end_date_to])
      @projects = @projects.select { |project| end_date_range.cover?(Date.parse(date_value(project, 'Scheduled End Date'))) }
    end

    @projects = @projects.select { |project| project.members.exists?(user_id: current_user_id) }
    @categories = @projects.map { |project| custom_field_value(project, 'Portfolio Category') }.compact.uniq
    @functions = @projects.map { |project| custom_field_value(project, 'User Function') }.compact.uniq
    @templates = @projects.map { |project| custom_field_value(project, 'Template') }.compact.uniq
    @statuses = @projects.map { |project| @project_status_text[project.status] }.compact.uniq
    @managers = @projects.flat_map { |project| member_names(project, 'Project Manager') }.compact.uniq

    @names = @projects.map(&:name).compact.uniq
    # Projects going live next week
    start_date_next_week = Date.today.next_week.beginning_of_week
    end_date_next_week = Date.today.next_week.end_of_week
    @next_week_go_live_projects = @projects.select { |project| 
      go_live_date = Date.parse(date_value(project, 'Planned Project Go Live Date'))
      go_live_date >= start_date_next_week && go_live_date <= end_date_next_week
    }

    # Remove this line if you don't want to limit to the first 3 projects
    @next_week_go_live_projects = @next_week_go_live_projects[0..2]
    rescue => e
    end
  end
  
  def member_names(project, field_name)
    project_lead_role = Role.find_by(name: field_name)
  
    member_ids_with_lead_role = MemberRole.where(role_id: project_lead_role.id).pluck(:member_id)
    project_lead_user_ids = Member.where(project_id: project.id, id: member_ids_with_lead_role).pluck(:user_id)
  
    if project_lead_user_ids.present?
      project_lead_users = User.where(id: project_lead_user_ids)
      project_lead_names = project_lead_users.pluck(:firstname, :lastname)
      return project_lead_names.map { |firstname, lastname| "#{firstname} #{lastname}" }
    else
      return []
    end
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

  def send_weekly_status_report(format)
    # Generate the weekly status report based on the specified format (csv or pdf)
    report_data = generate_report_data

    case format
    when 'csv'
      generate_csv_report(report_data)
    when 'pdf'
      generate_pdf_report(report_data)
    else
      raise ArgumentError, "Invalid report format: #{format}. Supported formats are 'csv' and 'pdf'."
    end

    # Print a message indicating the report was generated
    puts "Weekly status report generated in #{format} format."
  end

  private

  def generate_report_data
    # Logic to fetch data for the weekly status report
    # This could involve querying the database or any other data source
    # For demonstration purposes, let's return dummy data
    Issue.where(status_id: [1, 2, 3])  # Example: Fetch issues with open, in progress, or re-opened statuses
  end

  def generate_csv_report(report_data)
    # Logic to generate the CSV report
    # For simplicity, let's print the report data
    puts "CSV Report:"
    report_data.each do |issue|
      puts "#{issue.id}, #{issue.subject}, #{issue.status.name}, #{issue.assigned_to&.name}"
    end
  end

  def generate_pdf_report(report_data)
    # Logic to generate the PDF report
    # For simplicity, let's print the report data
    puts "PDF Report:"
    report_data.each do |issue|
      puts "#{issue.id} | #{issue.subject} | #{issue.status.name} | #{issue.assigned_to&.name}"
    end
  end

end

