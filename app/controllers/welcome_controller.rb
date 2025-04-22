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
  include WelcomeHelper
  before_action :set_projects, only: [:project_score_card,  :calculate_delay_percentage, :resource_management, :export_resource_management_to_csv, :export_project_score_to_csv]

  
  skip_before_action :check_if_login_required, only: [:robots]

  def download_help_documents
    document = Document.find(params[:id]) # Fetch the document by ID
    # Check if the document has an associated attachment (or file)
    if document && document.attachments.any?
      # Send the file for download
      attachment = document.attachments.first
      
      send_file attachment.diskfile,
                filename: attachment.filename,
                type: attachment.content_type,
                disposition: 'attachment' # Forces download
    else
      # If the document or attachment doesn't exist, respond with a 404
      head :not_found
    end
  end

  def resource_management
    @projects = @projects.where(status: 1)
    @roles = Role.all.where.not(name: ["Anonymous", "Non member"]).pluck(:name)
    binding.pry
    @members = Member.includes(:user).where(project_id: @project.id)
    if params[:roles].present? && params[:members].present?
      role = Role.where(name: params[:roles])
      member = User.where(firstname: params[:members].map { |name| name.split(' ').first }, lastname: params[:members].map { |name| name.split(' ').last })

      if role && member
        member_role_ids = MemberRole.where(role_id: role.pluck(:id)).pluck(:member_id)
        member_ids = Member.where(id: member_role_ids, user_id: member.pluck(:id)).pluck(:project_id)
        @projects = @projects.where(id: member_ids)
        # Extract project owner names for the filtered project
        if role.count == 1 && member.count == 1 && role.first.name == "Program Manager"
          @program_managers = ["#{member.first.firstname} #{member.first.lastname}"]
        else
          @program_managers = @projects.flat_map { |project| member_names(project, 'Program Manager') }.compact.uniq.sort
        end
        @program_managers.compact
      else
        return []
      end
    else
      @program_managers = @projects.flat_map { |project| member_names(project, 'Program Manager') }.compact.uniq.sort
    end
  end

  def export_resource_management_to_csv
    @projects = @projects.where(status: 1)
    @roles = Role.all.where.not(name: ["Anonymous", "Non member"]).pluck(:name)
    @members = User.all
    if params[:roles].present? && params[:members].present?
      role = Role.where(name: params[:roles])
      member = User.where(firstname: params[:members].map { |name| name.split(' ').first }, lastname: params[:members].map { |name| name.split(' ').last })

      if role && member
        member_role_ids = MemberRole.where(role_id: role.pluck(:id)).pluck(:member_id)
        member_ids = Member.where(id: member_role_ids, user_id: member.pluck(:id)).pluck(:project_id)
        @projects = @projects.where(id: member_ids)
        # Extract project owner names for the filtered projects
        @program_managers = @projects.flat_map { |project| member_names(project, 'Program Manager') }.compact.uniq.sort
        @program_managers.compact
      else
        return []
      end
    else
      @program_managers = @projects.flat_map { |project| member_names(project, 'Program Manager') }.compact.uniq.sort
    end
    # Generate CSV based on filtered projects
    csv_data = CSV.generate(headers: true) do |csv|
      # Adding header row to CSV
      csv << ["Program Manager", "Project Manager", "Project Assigned", "% Work Allocation", "Last Activity Due Date (Projects)", "Last Activity Due Date (Tasks)", "Total Hours/Month (Project Overview)", "Total Hours/Month (Assigned Activity)"]
      
      @program_managers.each do |program_manager|
        project_managers_data = get_project_manager_for_program_manager(@projects, program_manager)
        project_managers = project_managers_data[:project_managers]
        
        project_managers.each do |project_manager|
          project_manager_projects = @projects.select { |project| member_names(project, 'Project Manager').include?(project_manager) }
          project_count = project_manager_projects.count
          work_allocation = total_work_allocation(project_manager, project_manager_projects, "Work Allocation").join(", ")
          last_activity_due_date_project = last_activity_from_all_projects(project_manager, project_manager_projects, "Scheduled End Date")
          last_activity_due_date_task = last_activity_from_all_assigned_task(project_manager, project_manager_projects, "Project Activity")
          total_hours_project = working_duration_across_projects(project_manager_projects)
          total_hours_task = working_duration_across_assigned_tasks(project_manager_projects, project_manager)
  
          # Write a row to the CSV
          csv << [
            program_manager,
            project_manager,
            project_count,
            work_allocation.empty? ? "" : work_allocation,
            last_activity_due_date_project,
            last_activity_due_date_task,
            total_hours_project,
            total_hours_task
          ]
        end
      end
    end
  
    # Send the CSV data as a response for download
    send_data csv_data, filename: "resource_management.csv", type: "text/csv"
  end

  def member_names_by_role(projects, role)
    projects.flat_map { |project| member_names(project, role) }.compact.uniq.sort
  end

  def export_project_score_to_csv
       # Define project status text
       @project_status_text = {
        Project::STATUS_ACTIVE => 'Active',
        Project::STATUS_HOLD => "Hold",
        Project::STATUS_GO_LIVE => 'Go Live',
        Project::STATUS_CLOSED => 'Closed',
        Project::STATUS_CANCELLED => "Cancelled"
      }
     
    filter_type = params[:filter_type]  # e.g., 'category', 'priority', 'last-year'
    filter_value = params[:filter_value]  # e.g., 'high', 'finance', 'delayed'
    status_value = Project::STATUS_MAP.key(params[:status_value])
    today = Date.today
    @financial_year_start, @financial_year_end = if today.month < 4
      [Date.new(today.year - 1, 4, 1), Date.new(today.year, 3, 31)]
    else
      [Date.new(today.year, 4, 1), Date.new(today.year + 1, 3, 31)]
    end

    @total_last_year = calculate_delay_percentage(2.years.ago.change(month: 4, day: 1), 1.year.ago.change(month: 3, day: 31))
    @total_year_to_date = calculate_delay_percentage(@financial_year_start, @financial_year_end)
    @total_this_month = calculate_delay_percentage(Time.current.beginning_of_month, Time.current.end_of_month)
    # Get projects based on selected filter
    filtered_projects = case filter_type
                        when 'category'
                          filter_projects_by_status_and_field_name(@projects, params[:program_manager_usernames], params[:project_manager_usernames], status_value, filter_value, "Project Category")
                        when 'priority'
                          filter_projects_by_status_and_field_name(@projects, params[:program_manager_usernames], params[:project_manager_usernames], status_value, filter_value, "Priority Level")
                        when 'last-year'
                          if filter_value == 'delayed'
                            @total_last_year[:delayed_projects]
                          elsif filter_value == 'ontime'
                            @total_last_year[:ontime_projects]
                          else
                            @projects
                          end
                        when 'year-to-date'
                          if filter_value == 'delayed'
                            @total_year_to_date[:delayed_projects]
                          elsif filter_value == 'ontime'
                            @total_year_to_date[:ontime_projects]
                          else
                            @projects
                          end
                        when 'this-month'
                          if filter_value == 'delayed'
                            @total_this_month[:delayed_projects]
                          elsif filter_value == 'ontime'
                            @total_this_month[:ontime_projects]
                          else
                            @projects
                          end
                        when 'top-delayed'
                          @top_delayed_projects.map { |data| data[:project] }
                        else
                          @projects
                        end

    # Generate CSV
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ["Project", "Status", "Category", "Scheduled End", "Actual End", "RAG Status"]

      filtered_projects.each do |project|
        csv << [
          project.name,
          @project_status_text[project.status],
          custom_field_value(project, "Project Category")&.split(',')&.join(', '),
          formatted_date(date_value(project, "Scheduled End Date")),
          formatted_date(date_value(project, "Actual End Date")),
          ""
        ]
      end
    end
  
    send_data csv_data, filename: "#{filter_type}_#{filter_value}.csv", type: "text/csv"
  end

  def project_score_card
    params[:type] ||= "Project" 
    if params[:type] == "Project"

      # Define project status text
      @project_status_text = {
        Project::STATUS_ACTIVE => 'Active',
        Project::STATUS_HOLD => "Hold",
        Project::STATUS_GO_LIVE => 'Go Live',
        Project::STATUS_CLOSED => 'Closed',
        Project::STATUS_CANCELLED => "Cancelled"
      }
    
      # Calculate financial year start and end dates
      today = Date.today
      @financial_year_start, @financial_year_end = if today.month < 4
        [Date.new(today.year - 1, 4, 1), Date.new(today.year, 3, 31)]
      else
        [Date.new(today.year, 4, 1), Date.new(today.year + 1, 3, 31)]
      end
      # Fetch program managers and project managers
      @program_manager_usernames = @projects.flat_map { |project| member_names(project, 'Program Manager') }.compact.uniq.sort
      @project_manager_usernames = @projects.flat_map { |project| member_names(project, 'Project Manager') }.compact.uniq.sort
    # Fetch project categories and priorities from custom fields
      project_category_id = CustomField.find_by(name: "Project Category")&.id
      @categories = CustomFieldEnumeration.where(custom_field_id: project_category_id).pluck(:name) if project_category_id

      priority_level_id = CustomField.find_by(name: "Priority Level")&.id
      @priorities = CustomFieldEnumeration.where(custom_field_id: priority_level_id).pluck(:name) if priority_level_id
      application_name_id = CustomField.find_by(name: "Application Name")&.id
      @application_names = CustomFieldEnumeration.where(custom_field_id: application_name_id).pluck(:name) if application_name_id
      # Fetch closed projects and calculate top delayed projects
      @it_closed_projects = @projects.where(status: Project::STATUS_CLOSED)
      @filter_projects = @projects
      @filter_projects = @filter_projects.select { |project| (Array(params[:program_manager_usernames]) & member_names(project, 'Program Manager')).any? } if params[:program_manager_usernames].present?
      @filter_projects = @filter_projects.select { |project| (Array( params[:project_manager_usernames]) & member_names(project, 'Project Manager')).any? } if  params[:project_manager_usernames].present?

      @active_projects = @filter_projects.select { |p| p.status == Project::STATUS_ACTIVE }.count
      @closed_projects = @filter_projects.select { |p| p.status == Project::STATUS_CLOSED }.count
      @hold_projects = @filter_projects.select { |p| p.status == Project::STATUS_HOLD }.count
      @cancelled_projects = @filter_projects.select { |p| p.status == Project::STATUS_CANCELLED }.count
      @go_live_projects = @filter_projects.select { |p| p.status == Project::STATUS_GO_LIVE }.count
      @top_delayed_projects = get_top_delayed_projects(@it_closed_projects)

      # Calculate delay percentages for last year, year-to-date, and this month
      @total_last_year = calculate_delay_percentage(2.years.ago.change(month: 4, day: 1), 1.year.ago.change(month: 3, day: 31))
      @total_year_to_date = calculate_delay_percentage(@financial_year_start, @financial_year_end)
      @total_this_month = calculate_delay_percentage(Time.current.beginning_of_month, Time.current.end_of_month)
    elsif params[:type] == "Business Requirment"
      @project_status_text = {
        BusinessRequirement::STATUS_IN_DISCUSSION => 'In Discussion',
        BusinessRequirement::STATUS_REQUIREMENT_FINILIZED => 'Requirement Finalized',
        BusinessRequirement::STATUS_AWAITING_DETAILS => 'Awaiting Details',
        BusinessRequirement::STATUS_AWATING_BUSINESS_CASE => 'Awaiting Business Case',
        BusinessRequirement::STATUS_REQUIREMENT_NOT_APPROVED => 'Requirement Not Approved',
        BusinessRequirement::STATUS_REQUIREMENT_ON_HOLD => 'Requirement On Hold',
        BusinessRequirement::STATUS_ACCEPTED => 'Accepted',
        BusinessRequirement::STATUS_CANCELLED   => 'Cancelled',
        BusinessRequirement::STATUS_CLOSED => 'Closed'
      }
      @business_requirements = BusinessRequirement.all
      @project_manager_usernames = BrStakeholder.includes(:user).where(role_id: Role.find_by(name: "Project Manager")&.id).map { |stakeholder| "#{stakeholder.user.firstname} #{stakeholder.user.lastname}" }
      @program_manager_usernames = BrStakeholder.includes(:user).where(role_id: Role.find_by(name: "Program Manager")&.id).map { |stakeholder| "#{stakeholder.user.firstname} #{stakeholder.user.lastname}" }
      @categories = @business_requirements.pluck(:project_category).flatten.reject { |val| val.blank? }.uniq
      @priorities = @business_requirements.pluck(:priority_level).flatten.reject { |val| val.blank? }.uniq
      @application_names = @business_requirements.pluck(:application_name).flatten.reject { |val| val.blank? }.uniq
      if params[:program_manager_usernames].present?
        program_manager_role = Role.find_by(name: "Program Manager")
        program_manager_names = params[:program_manager_usernames].map { |name| name.split.map(&:capitalize).join(' ') }
        user_ids = User.where("CONCAT(firstname, ' ', lastname) IN (?)", program_manager_names).pluck(:id)
    
        @business_requirements = @business_requirements.joins(:br_stakeholders)
                                                     .where(br_stakeholders: { user_id: user_ids, role_id: program_manager_role.id })
      end
    
      # Filter by Project Manager if present
      if params[:project_manager_usernames].present?
        project_manager_role = Role.find_by(name: "Project Manager")
        project_manager_names = params[:project_manager_usernames].map { |name| name.split.map(&:capitalize).join(' ') }
        user_ids = User.where("CONCAT(firstname, ' ', lastname) IN (?)", project_manager_names).pluck(:id)
    
        @business_requirements = @business_requirements.joins(:br_stakeholders)
                                                     .where(br_stakeholders: { user_id: user_ids, role_id: project_manager_role.id })
      end
      @active_projects = @business_requirements.select { |p| p.status == BusinessRequirement::STATUS_IN_DISCUSSION }.count
      @closed_projects = @business_requirements.select { |p| p.status == BusinessRequirement::STATUS_ACCEPTED }.count
      @hold_projects = @business_requirements.select { |p| p.status == BusinessRequirement::STATUS_CANCELLED }.count
      @cancelled_projects = @business_requirements.select { |p| p.status == BusinessRequirement::STATUS_REQUIREMENT_FINILIZED }.count
      @go_live_projects = @business_requirements.select { |p| p.status == BusinessRequirement::STATUS_AWATING_BUSINESS_CASE}.count
    end
  end
  
  def it_project_ids
    custom_field = CustomField.find_by(name: "Is IT Project?")
    CustomValue.where(custom_field_id: custom_field.id, value: "1").pluck(:customized_id)
  end

  def calculate_average_delay(projects)
    total_delay = 0
    valid_projects_count = 0
    
    projects.each do |project|
      planned_project_go_live_date = fetch_custom_field_date(project, 'Planned Project Go Live Date')

      cf = CustomField.find_by(name: "Actual End Date")
      cv = CustomValue.find_by(customized_type: "Project", customized_id: project.id, custom_field_id: cf.id)
      actual_end_date = cv&.value&.to_date
      
      next unless planned_project_go_live_date && actual_end_date
      
      delay = (actual_end_date - planned_project_go_live_date).to_i
      next if delay <= 0
      
      total_delay += delay
      valid_projects_count += 1
    end
    return 0 if valid_projects_count.zero?
    total_delay / projects.count
  end

  def fetch_custom_field_date(project, field_name)
    custom_field = CustomField.find_by(name: field_name)
    return unless custom_field
    
    custom_field_value = project.custom_field_values.find { |cfv| cfv.custom_field_id == custom_field.id }
    custom_field_value&.value&.to_date
  end

  def get_top_delayed_projects(projects)
    holidays = [
      Date.new(Date.today.year, 1, 26),
      Date.new(Date.today.year, 8, 15),
      Date.new(Date.today.year, 10, 2),
      Date.new(Date.today.year, 12, 25),
      Date.new(Date.today.year, 5, 1)
    ]
    
    delayed_projects = projects.map do |project|
      scheduled_end_date = fetch_custom_field_date(project, 'Scheduled End Date')

      cf = CustomField.find_by(name: "Actual End Date")
      cv = CustomValue.find_by(customized_type: "Project", customized_id: project.id, custom_field_id: cf.id)
      actual_end_date = cv&.value&.to_date
      
      next unless scheduled_end_date && actual_end_date
      # delay = (actual_end_date - scheduled_end_date).to_i

      working_days = 0
      current_date = scheduled_end_date
      while current_date <= actual_end_date

        unless current_date.sunday? || holidays.include?(current_date)
          working_days += 1
        end
        current_date = current_date.next_day
      end
      next unless working_days > 0
      { project: project, delay: working_days,  actual_end_date: actual_end_date}
    end.compact
    delayed_projects.sort_by { |data| -data[:actual_end_date].to_time.to_i }.take(3)
  end

  def calculate_delay_percentage(start_date, end_date)
    total_projects = 0
    delayed_projects = []
    ontime_projects = []
    @it_closed_projects = @projects.select { |project| project.status == Project::STATUS_CLOSED }
    @it_closed_projects = @it_closed_projects.select { |project| (Array(params[:program_manager_usernames]) & member_names(project, 'Program Manager')).any? } if params[:program_manager_usernames].present?
    @it_closed_projects = @it_closed_projects.select { |project| (Array( params[:project_manager_usernames]) & member_names(project, 'Project Manager')).any? } if  params[:project_manager_usernames].present?
    @it_closed_projects.each do |project|
      scheduled_end_date = fetch_custom_field_date(project, 'Scheduled End Date')
      next unless scheduled_end_date && scheduled_end_date.between?(start_date, end_date)
  
      total_projects += 1
      actual_end_date = fetch_custom_field_date(project, 'Actual End Date')
  
      if actual_end_date
        working_days = calculate_working_days(scheduled_end_date, actual_end_date)
        if working_days > 0
          delayed_projects << project
        else
          ontime_projects << project
        end
      end
    end
    delayed_count = delayed_projects.size
    ontime_count = ontime_projects.size
    percentage = total_projects.zero? ? 0 : ((total_projects - ontime_count) / total_projects.to_f * 100).round(2)
    {
      percentage: percentage,
      delayed_projects: delayed_projects,
      ontime_projects: ontime_projects
    }
  end
  
  def calculate_working_days(start_date, end_date)
    holidays = [
      Date.new(Date.today.year, 1, 26),
      Date.new(Date.today.year, 8, 15),
      Date.new(Date.today.year, 10, 2),
      Date.new(Date.today.year, 12, 25),
      Date.new(Date.today.year, 5, 1)
    ]
    working_days = 0
    (start_date...end_date).each do |date|
      working_days += 1 unless date.sunday? || holidays.include?(date)
    end
    working_days
  end

  def date_value(project, field_name)
    custom_field = CustomField.find_by(name: field_name)
    custom_value = CustomValue.find_by(customized_type: "Project", customized_id: project&.id, custom_field_id: custom_field&.id)
    date_string = custom_value&.value
  end

  def it_project_dashboard 
    cache_key = cache_key_for_dashboard
    cached_data = REDIS.get(cache_key)
    # if cached_data
    #   @projects, @categories, @functions, @statuses, @managers, @names, @subprojects, @next_week_go_live_projects = Marshal.load(cached_data)
    # else
      @project_status_text = {
        Project::STATUS_ACTIVE => 'Active',
        Project::STATUS_CLOSED => 'Closed',
        Project::STATUS_ARCHIVED => 'Archived',
        Project::STATUS_SCHEDULED_FOR_DELETION => 'Scheduled for Deletion',
        Project::STATUS_HOLD => "Hold",
        Project::STATUS_CANCELLED => "Cancelled"
      }
    
      # Optimize the subproject filter

      current_user_id = User.current.id
      name_filter = Array(params[:name_filter]).reject(&:blank?)
      if name_filter.any? && !name_filter.include?('all')
        @projects = Project.where(name: name_filter)
      else
        @projects = Project.where(parent_id: nil)
      end

      if params[:show_subprojects] == 'true'
        selected_project_ids = @projects.pluck(:id)
        subprojects = Project.where(parent_id: selected_project_ids)
        @projects = @projects.or(subprojects)
      else
        @projects = @projects.where(parent_id: nil)
      end

      @projects = @projects.joins("LEFT JOIN custom_values ON custom_values.customized_id = projects.id AND custom_values.customized_type = 'Project'")
        .joins("LEFT JOIN custom_fields ON custom_fields.id = custom_values.custom_field_id")
        .where("custom_fields.name = ?", 'Planned Project Go Live Date')
        .order("custom_values.value DESC")

      custom_field = CustomField.find_by(name: "Is It Project?")
      customized_ids = CustomValue.where(custom_field_id: custom_field.id, value: "1").pluck(:customized_id)

      @projects = @projects.where.not(name: "Master Project").where(id: customized_ids)
      @categories =@projects.map { |project| custom_field_value(project, 'Portfolio Category') }.compact.flatten.uniq
      @functions = @projects.flat_map { |project| custom_field_value(project, 'Function') }.compact.uniq
      @statuses = @projects.map { |project| @project_status_text[project.status] }.compact.uniq.sort
      @managers = @projects.flat_map { |project| member_names(project, 'Project Manager') }.compact.uniq.sort
      @program_managers = @projects.flat_map { |project| member_names(project, 'Program Manager') }.compact.uniq.sort
      @names = @projects.select { |project| project.parent_id.nil? }.map(&:name).uniq.sort
      @subprojects = @projects.select { |project| !project.parent_id.nil? }.map(&:name).uniq.sort

      @projects = @projects.joins("LEFT JOIN custom_values ON custom_values.customized_id = projects.id AND custom_values.customized_type = 'Project'")
      .joins("LEFT JOIN custom_fields ON custom_fields.id = custom_values.custom_field_id")
      .where("custom_fields.name = ?", 'Planned Project Go Live Date')
      .order("custom_values.value DESC")
      custom_field = CustomField.find_by(name: "Is It Project?")
      customized_ids = CustomValue.where(custom_field_id: custom_field.id, value: "1").pluck(:customized_id)
      @projects = @projects.where.not(name: "Master Project").where(id: customized_ids)
      @projects = @projects.where(status: Array(params[:status_filter])) if params[:status_filter].present?

      @projects = @projects.select { |project| member_names(project, 'Project Manager').include?(params[:manager_filter]) } if params[:manager_filter].present?
      @projects = @projects.select { |project| member_names(project, 'Program Manager').include?(params[:program_manager_filter]) } if params[:program_manager_filter].present?
      @projects = @projects.select{|project| custom_field_value(project, 'Project Category')&.include?(params[:category_filter])} if params[:category_filter].present?

      @projects = @projects.select do |project|
        function_values = custom_field_value(project, 'Function')
        if function_values.is_a?(Array)
          function_values.any? { |value| value.casecmp?(params[:function_filter]) }
        else
          function_values&.casecmp?(params[:function_filter])
        end
      end if params[:function_filter].present?
      if params[:start_date_from].present? && params[:start_date_to].present?
        start_date_range = Date.parse(params[:start_date_from])..Date.parse(params[:start_date_to])
        
        @projects = @projects.select do |project|
          start_date_str = date_value(project, 'Scheduled Start Date')
          next false unless start_date_str.present?
          
          start_date = Date.parse(start_date_str) 
          start_date_range.cover?(start_date) 
        end
      end

      if params[:end_date_from].present? && params[:end_date_to].present?
        end_date_range = Date.parse(params[:end_date_from])..Date.parse(params[:end_date_to])
        
        @projects = @projects.select do |project|
          end_date_str = date_value(project, 'Scheduled End Date') 
          next false unless end_date_str.present? 
          
          end_date = Date.parse(end_date_str) 
          end_date_range.cover?(end_date) 
        end
      end
      
      if User.current.admin?
        @projects# Show all projects if the user is an admin
      else
        @projects = @projects.select { |project| project.members.exists?(user_id: current_user_id) }  # Show only projects the user is a member of
      end

      # Projects going live next week
      start_date_next_week = Date.today.next_week.beginning_of_week
      end_date_next_week = Date.today.next_week.end_of_week
      @next_week_go_live_projects = @projects.select { |project| 
        begin
          # Fetch the 'Revised End Date' value
          revised_end_date_str = date_value(project, 'Revised End Date')
          
          if revised_end_date_str.present?
            revised_end_date = Date.parse(revised_end_date_str)
            revised_end_date >= start_date_next_week && revised_end_date <= end_date_next_week
          else
            # If 'Revised End Date' is not present, check 'Planned Project Go Live Date'
            go_live_date_str = date_value(project, 'Planned Project Go Live Date')
            
            if go_live_date_str.present?
              go_live_date = Date.parse(go_live_date_str)
              go_live_date >= start_date_next_week && go_live_date <= end_date_next_week
            else
              false
            end
          end
        rescue ArgumentError, TypeError
          # Return false if parsing fails due to invalid date format or nil
          false
        end
      }
      if params[:program_manager_filter].present?
        @filtered_columns = ["Project Name", "BR ID", "Status", "Project Manager", "Project Lead", "Project Size", "Next Week Planned Activity", "Last Activity Completed", "Portfolio Category", "Remarks"]
        @filtered_by_pm = true  # Flag set karenge taki view me condition lag sake
      else
        @filtered_by_pm = false
        @filtered_columns = ["Project Name", "BR ID", "Status", "Project Manager", "Project Lead", "Project Size", "Next Week Planned Activity", "Last Activity Completed", "Portfolio Category", "Scheduled Start Date", "Scheduled End Date", "Go Live Date", "Revised End Date", "Last Activity Due Date", "Function Name", "Document Uploaded", "Task View", "% Done", "Delay (Days)"]
      end
     # without pagination
      @total_project = @projects
      # Paginate through the existing projects
      @projects = @projects.paginate(page: params[:page], per_page: 5)
      REDIS.set(cache_key, Marshal.dump([@projects, @categories, @functions, @statuses, @managers, @names, @subprojects, @next_week_go_live_projects]), ex: 5.minutes.to_i)
    # end
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
    custom_field = CustomField.find_by(name: "Is IT Project?")
    customized_ids = CustomValue.where(custom_field_id: custom_field.id, value: "0").pluck(:customized_id)
    @projects = @projects.where(id: customized_ids)
    @projects = @projects.where("custom_field_value(project, 'Project Category') = ?", params[:category_filter]) if params[:category_filter].present?

    @projects = @projects.where("custom_field_value(project, 'Function') = ?", params[:function_filter]) if params[:function_filter].present?
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
 
    @functions = @projects.map { |project| custom_field_value(project, 'Function') }.compact.uniq
    @templates = @projects.map { |project| custom_field_value(project, 'Template') }.compact.uniq
    @statuses = @projects.map { |project| @project_status_text[project.status] }.compact.uniq
    @managers = @projects.flat_map { |project| member_names(project, 'Project Manager') }.compact.uniq
    @top_delayed_projects = get_top_delayed_projects(@projects)
    @average_delay = calculate_average_delay(@projects)
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
  
  def export_all_it
  end


  def custom_field_value(project, field_name)
    if field_name = "Function"
    custom_field = CustomField.find_by(name: field_name)
    custom_values = CustomValue.where(customized_type: "Project", customized_id: project&.id, custom_field_id: custom_field&.id)
    custom_field_enumerations = custom_values.map do |cv|
      CustomFieldEnumeration.find_by(id: cv.value.to_i)
    end.compact
    custom_field_enumerations.map(&:name) # Or handle the names as needed
  end

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

  def set_projects
    @projects = Project.all
    @projects = @projects.where(id: it_project_ids, parent_id: nil).where.not(name: "Master Project")
  end

  def formatted_date(date_string)
    return "" if date_string.nil?

    begin
      date = Date.parse(date_string)
      date.strftime("%d %b %y")
    rescue ArgumentError
      ""
    end
  end

  def cache_key_for_dashboard
    "dashboard/#{params[:name_filter].to_s}/#{params[:show_subprojects]}/#{params[:category_filter]}/#{params[:function_filter]}/#{params[:status_filter]}/#{params[:manager_filter]}/#{params[:start_date_from]}/#{params[:start_date_to]}/#{params[:end_date_from]}/#{params[:end_date_to]}/#{Date.today.to_s}"
  end
  
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

