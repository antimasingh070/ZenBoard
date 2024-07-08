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

  def working_days_between(start_date, end_date)
    end_date = end_date.value.to_date

    holidays = [
      Date.new(Date.today.year, 1, 26),
      Date.new(Date.today.year, 8, 15),
      Date.new(Date.today.year, 10, 2),
      Date.new(Date.today.year, 12, 25),
      Date.new(Date.today.year, 5, 1)
    ]

    working_days = 0
    current_date = start_date

    while current_date <= end_date
      unless current_date.sunday? || holidays.include?(current_date)
        working_days += 1
      end
      current_date = current_date.next_day
    end

    working_days
  end

  def custom_field_value(project, field_name)
    if field_name == "Project Activity"
      custom_field = CustomField.find_by(name: field_name)
      return "" unless custom_field

      custom_value = CustomValue.find_by(customized_type: "Issue", customized_id: project.issues.where(status: 5)&.order(updated_on: :desc)&.last&.id, custom_field_id: custom_field&.id)
      return "" unless custom_value

      custom_field_enumeration = CustomFieldEnumeration.find_by(id: custom_value&.value&.to_i)
      completed_date = ""
      last_issue = project.issues.where(status: 5).order(updated_on: :desc).last
      if last_issue
        custom_value = CustomValue.find_by(customized_type: "Issue", customized_id: last_issue.id, custom_field_id: custom_field.id)
        completed_date = last_issue.closed_on.strftime("%d %b %y") if last_issue.closed_on
      end
      "#{custom_field_enumeration&.name} (#{completed_date})" || ''
    else
      custom_field = CustomField.find_by(name: field_name)
      return "" unless custom_field
    
      custom_value = CustomValue.find_by(customized_type: "Project", customized_id: project&.id, custom_field_id: custom_field&.id)
      return "" unless custom_value
    
      custom_field_enumeration = CustomFieldEnumeration.find_by(id: custom_value&.value&.to_i)
      custom_field_enumeration&.name || ''
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
  
    closed_issue_count = Issue.where(project_id: project&.id, tracker_id: tracker_id, status_id: [3,5])&.count
    ((closed_issue_count.to_f / total_issue_count.to_f ) * 100).round()

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
    open_issue_count = Issue.where(project_id: [project.id] + project_ids, tracker_id: tracker_id, status_id: [1,2,4,6,7]).count
    total_issue_count = Issue.where(project_id: [project.id] + project_ids, tracker_id: tracker_id).count 
    return "#{open_issue_count} / #{total_issue_count}"
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
    else
      ''
    end
  end

end
