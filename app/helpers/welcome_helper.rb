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

module WelcomeHelper
  # Define project status text
  @project_status_text = {
    Project::STATUS_ACTIVE => 'Active',
    Project::STATUS_CLOSED => 'Closed',
    Project::STATUS_ARCHIVED => 'Archived',
    Project::STATUS_SCHEDULED_FOR_DELETION => 'Scheduled for Deletion',
    Project::STATUS_HOLD => "Hold",
    Project::STATUS_CANCELLED => "Cancelled"
  }

  # Define the holidays as a constant
  HOLIDAYS = [
    Date.new(Date.today.year, 1, 26),  # Republic Day
    Date.new(Date.today.year, 5, 1),   # Labor Day
    Date.new(Date.today.year, 8, 15),  # Independence Day
    Date.new(Date.today.year, 10, 2),  # Gandhi Jayanti
    Date.new(Date.today.year, 12, 25)  # Christmas
  ].freeze

  def business_requirement_count(business_requirements, type, field_name, program_manager, project_manager, status = nil)
    # Filter by status if provided
    business_requirements = business_requirements.select { |br| br.status == status } if status.present?

    # Filter by Program Manager if present
    if program_manager.present?
      program_manager_role = Role.find_by(name: "Program Manager")
      program_manager_names = program_manager.map { |name| name.split.map(&:capitalize).join(' ') }
      user_ids = User.where("CONCAT(firstname, ' ', lastname) IN (?)", program_manager_names).pluck(:id)

      business_requirements = business_requirements.joins(:br_stakeholders)
                                                   .where(br_stakeholders: { user_id: user_ids, role_id: program_manager_role.id })
    end

    # Filter by Project Manager if present
    if project_manager.present?
      project_manager_role = Role.find_by(name: "Project Manager")
      project_manager_names = project_manager.map { |name| name.split.map(&:capitalize).join(' ') }
      user_ids = User.where("CONCAT(firstname, ' ', lastname) IN (?)", project_manager_names).pluck(:id)

      business_requirements = business_requirements.joins(:br_stakeholders)
                                                   .where(br_stakeholders: { user_id: user_ids, role_id: project_manager_role.id })
    end

    # Filter by Custom Field
    if type.present?
      case field_name
      when "Project Category"
        business_requirements = business_requirements.select { |br| Array(br.project_category).include?(type) }
      when "Priority Level"
        business_requirements = business_requirements.select { |br| Array(br.priority_level).include?(type) }
      when "Application Name"
        business_requirements = business_requirements.select { |br| Array(br.application_name).include?(type) }
      end
    end

    business_requirements.count
  end

  def project_count(projects, type, field_name, program_manager, project_manager, status = nil)
    projects = projects.select { |project| project.status == status } if status.present?
    projects = projects.select { |project| (Array(program_manager) & member_names(project, 'Program Manager')).any? } if program_manager.present?
    projects = projects.select { |project| (Array(project_manager) & member_names(project, 'Project Manager')).any? } if project_manager.present?
    case field_name
    when "Project Category"
      projects = projects.select { |project| custom_field_value(project, 'Project Category')&.include?(type) } if type.present?
    when "Priority Level"
      projects = projects.select { |project| custom_field_value(project, 'Priority Level')&.include?(type) } if type.present?
    when "Application Name"
      projects = projects.select { |project| custom_field_value(project, 'Application Name')&.include?(type) } if type.present?
    end
    projects.count
  end

  # Helper method to filter projects by status and category
  def filter_projects_by_status_and_field_name(projects, program_manager_filter, project_manager_filter, status, type, field_name)
    projects = projects.select { |project| project.status == status } if status.present?
    projects = projects.select { |project| (Array(program_manager_filter) & member_names(project, 'Program Manager')).any? } if program_manager_filter.present?
    projects = projects.select { |project| (Array(project_manager_filter) & member_names(project, 'Project Manager')).any? } if project_manager_filter.present?

    case field_name
    when "Project Category"
      projects = projects.select { |project| custom_field_value(project, 'Project Category')&.include?(type) } if type.present?
    when "Priority Level"
      projects = projects.select { |project| custom_field_value(project, 'Priority Level')&.include?(type) } if type.present?
    when "Application Name"
      projects = projects.select { |project| custom_field_value(project, 'Application Name')&.include?(type) } if type.present?
    end
    projects
  end


 def member_names(project, field_name)
    role = Role.find_by(name: field_name)
    if role.present?
      member_role_ids = MemberRole.where(role_id: role.id).pluck(:member_id)
      member_ids = Member.where(project_id: project.id, id: member_role_ids).pluck(:user_id)

      if member_ids.present?
        users = User.where(id: member_ids)
        full_names = users.pluck(:firstname, :lastname)
        return full_names.map { |firstname, lastname| "#{firstname} #{lastname}" }
      else
        return []
      end
    end
  end

  # Method to check if a day is a working day
  def working_day?(date)
    # Exclude Sundays
    return false if date.sunday?

    # Exclude 1st and 2nd Saturdays of the month
    return false if date.saturday? && (date.day <= 14)

    # Exclude holidays
    return false if HOLIDAYS.include?(date)

    true
  end

  # Method to calculate working days between two dates
  def working_days_between(start_date, end_date)
    # Ensure end_date is a Date object
    end_date = end_date.to_date if end_date.respond_to?(:to_date)

    working_days = 0
    current_date = start_date

    # Iterate through each date from start_date to end_date
    while current_date <= end_date
      # Count only working days
      working_days += 1 if working_day?(current_date)
      current_date = current_date.next_day
    end

    working_days
  rescue => e
    # Handle any exceptions that might occur
    Rails.logger.debug { "An error occurred: #{e.message}" }
    return 0  # Return 0 or handle as needed
  end

  def custom_field_value(project, field_name)
    custom_field = CustomField.find_by(name: field_name)
    return "" unless custom_field

    if field_name == "Project Activity"

      # Fetch issues with the specific status and tracker ID
      issues = project.issues.where(status: 5, tracker_id: 2).includes(:custom_values)
      custom_field_id = CustomField.find_by(name: "Actual End Date")&.id

      if custom_field_id
        sorted_issues = issues.sort_by do |issue|
          end_date_value = issue.custom_values.find { |cv| cv.custom_field_id == custom_field_id }&.value
          begin
            end_date_value ? Date.parse(end_date_value) : nil
          rescue ArgumentError
            # Handle parsing errors by returning nil
            nil
          end
        end
        last_issue_id = sorted_issues.last&.id
      end
      custom_value = CustomValue.find_by(customized_type: "Issue", customized_id: last_issue_id, custom_field_id: custom_field&.id)
      return "" unless custom_value

      custom_field_enumeration = CustomFieldEnumeration.find_by(id: custom_value&.value&.to_i)
      completed_date = ""
      last_issue = sorted_issues.last
      if last_issue
        custom_value = CustomValue.find_by(customized_type: "Issue", customized_id: last_issue.id, custom_field_id: custom_field.id)
        completed_date = last_issue.closed_on.strftime("%d %b %y") if last_issue.closed_on
      end

      "#{custom_field_enumeration&.name} (#{completed_date})" || ''
    else

      custom_values = CustomValue.where(customized_type: "Project", customized_id: project&.id, custom_field_id: custom_field&.id)
      custom_field_enumerations = custom_values.filter_map do |cv|
        CustomFieldEnumeration.find_by(id: cv.value.to_i)
      end
      custom_field_enumerations.map(&:name).join(', ') # Or handle the names as needed
    end
  end

  def custom_field_value_week(project, field_name)
    if field_name == "Project Activity"
      custom_field = CustomField.find_by(name: field_name)
      return "" unless custom_field

      start_date = Date.current
      due_date = Date.current + 7

      issues_within_week = project.issues
                              .where(start_date: start_date..due_date)
                              .where.not(status: 5)
                              .order(updated_on: :desc)

      return "" unless issues_within_week.any?

      custom_values = issues_within_week.map do |issue|
        custom_value = CustomValue.find_by(customized_type: "Issue", customized_id: issue.id, custom_field_id: custom_field.id)
        formatted_due_date = issue.due_date.strftime("%d %b %y") if issue.due_date
        "#{custom_value ? CustomFieldEnumeration.find_by(id: custom_value.value.to_i)&.name : nil} (#{formatted_due_date})"
      end

      custom_values.join(", ")
    else
      ""
    end
  end

  def member_name(project, field_name)
    project_lead_role = Role.find_by(name: field_name)
    return "" unless project_lead_role

    member_ids_with_lead_role = MemberRole.where(role_id: project_lead_role.id).pluck(:member_id)
    project_lead_user_ids = Member.where(project_id: project.id, id: member_ids_with_lead_role).pluck(:user_id)

    if project_lead_user_ids.present?
      project_lead_users = User.where(id: project_lead_user_ids)
      project_lead_names = project_lead_users.pluck(:firstname, :lastname)
      return project_lead_names.map { |firstname, lastname| "#{firstname} #{lastname}" }.join(", ")
    else
      return ""
    end
  end

  def date_value(project, field_name)
    custom_field = CustomField.find_by(name: field_name)
    custom_value = CustomValue.find_by(customized_type: "Project", customized_id: project&.id, custom_field_id: custom_field&.id)
    date_string = custom_value&.value
  end

  # Helper method to calculate % done
  def percentage_done(project)
    tracker_id = Tracker.find_by(name: "Project- Activity List")&.id
    total_issue_count = Issue.where(project_id: project&.id, tracker_id: tracker_id).count
    return 0 if total_issue_count.zero?

    closed_issue_count = Issue.where(project_id: project&.id, tracker_id: tracker_id, status_id: [3, 5])&.count
    ((closed_issue_count.to_f / total_issue_count) * 100).round
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

  def tracker_count(project, field_name)
    tracker_id = Tracker.find_by(name: field_name)&.id
    project_ids = Project.where(parent_id: project.id).ids
    open_issue_count = Issue.where(project_id: [project.id] + project_ids, tracker_id: tracker_id, status_id: [1, 2, 4, 6, 7]).count
    total_issue_count = Issue.where(project_id: [project.id] + project_ids, tracker_id: tracker_id).count

    delayed_issue = Issue.where(project_id: [project.id] + project_ids, tracker_id: tracker_id)
    delayed_issue_count = 0
    delayed_issue.each do |issue|
      due_date = issue.due_date
      revised_end_date = issue.custom_field_values.find{ |v| v.custom_field.name == 'Revised Planned Due Date'}.value

      if revised_end_date.present? && Date.parse(revised_end_date)  < Date.today
        delayed_issue_count += 1
      elsif due_date.present? && due_date < Date.today
        delayed_issue_count += 1
      end
    end

    return "#{delayed_issue_count} | #{open_issue_count} | #{total_issue_count}"
  end

  def status_id(status)
    case status
    when 'Active'
      Project::STATUS_ACTIVE
    when 'Closed'
      Project::STATUS_CLOSED
    when 'Archived'
      Project::STATUS_ARCHIVED
    when 'Scheduled for Deletion'
      Project::STATUS_SCHEDULED_FOR_DELETION
    when 'Hold'
      Project::STATUS_HOLD
    when 'Go Live'
      Project::STATUS_GO_LIVE
    else
      ''
    end
  end
end
