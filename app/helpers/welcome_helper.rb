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

  def custom_field_value(project, field_name)
    if field_name == "Project Activity"
      custom_field = CustomField.find_by(name: field_name)
      return "" unless custom_field

      custom_value = CustomValue.find_by(customized_type: "Issue", customized_id: project.issues.where(status: [3,5])&.order(updated_on: :desc)&.last&.id, custom_field_id: custom_field&.id)
      return "" unless custom_value

      custom_field_enumeration = CustomFieldEnumeration.find_by(id: custom_value&.value&.to_i)
      custom_field_enumeration&.name || ''
    else
      custom_field = CustomField.find_by(name: field_name)
      return "" unless custom_field
    
      custom_value = CustomValue.find_by(customized_type: "Project", customized_id: project&.id, custom_field_id: custom_field&.id)
      return "" unless custom_value
    
      custom_field_enumeration = CustomFieldEnumeration.find_by(id: custom_value&.value&.to_i)
      custom_field_enumeration&.name || ''
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
    tracker_id = Tracker.find_by(name: "Risk Register")&.id
    total_issue_count = Issue.where(project_id: project&.id, tracker_id: tracker_id).count
    return 0 if total_issue_count.zero?
  
    closed_issue_count = Issue.where(project_id: project&.id, tracker_id: tracker_id, status_id: [3,5])&.count
    ((closed_issue_count.to_f / total_issue_count.to_f ) * 100).round(2)

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
    else
      ''
    end
  end

end
