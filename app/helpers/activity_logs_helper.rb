# frozen_string_literal: true

# app/helpers/activity_logs_helper.rb
module ActivityLogsHelper
  def fetch_entity_name(log)
    case log.entity_type
    when 'Project'
      Project.find_by(id: log.entity_id)&.name || "Unknown Project"
    when 'Issue'
      old_value = log.old_value || {}
      new_value = log.new_value || {}
      author_name = User.find_by(id: log.author_id)&.firstname

      case log.field_name
      when 'Create'
        created_message(log.new_value, log.author_id, log.created_at)
      when 'Delete'
        deleted_message(log.old_value, log.author_id, log.created_at)
      else
        values = [log.old_value, log.new_value]
        updated_message(log, values, log.author_id, log.created_at)
      end
    when 'Tracker'
      Tracker.find_by(id: log.entity_id)&.name || "Unknown Tracker"
    when 'Member'
      member = Member.find_by(id: log.entity_id)
      if member
        user = User.find_by(id: member.user_id)
        if user
          project = Project.find_by(id: member.project_id)
          role = member.roles.map(&:name).join(", ")
          "#{user.user_full_name}in project #{project.name} with role #{role}"
        else
          "Unknown User"
        end
      else
        "Unknown Member"
      end
    when 'News'
      News.find_by(id: log.entity_id)&.title || "Unknown News"
    when 'Role'
      Role.find_by(id: log.entity_id)&.name || "Unknown Role"
    when 'CustomField'
      CustomField.find_by(id: log.entity_id)&.name || "Unknown Custom Field"
    when 'CustomValue'
      CustomValue.find_by(id: log.entity_id)&.value || "Unknown Custom Value"
    when 'Enumeration'
      Enumeration.find_by(id: log.entity_id)&.name || "Unknown Enumeration"
    when 'Setting'
      log.field_name || "Unknown Setting"
    when 'User'
      user = User.find_by(id: log.entity_id)
      user.user_full_name.to_s || "Unknown User"
    when 'MemberRole'
      case log.field_name
      when 'Create'
        created_role_name = Role.find_by(id: JSON.parse(log.new_value)['role_id'])&.name if log.new_value.present?
        member = Member.find_by(id: JSON.parse(log.new_value)['member_id']) if log.new_value.present?
      when 'Update'
        old_role_name = Role.find_by(id: JSON.parse(log.old_value)['role_id'])&.name if log.old_value.present?
        new_role_name = Role.find_by(id: JSON.parse(log.new_value)['role_id'])&.name if log.new_value.present?
        member = Member.find_by(id: log.entity_id)
      when 'Delete'
        deleted_role_name = Role.find_by(id: JSON.parse(log.old_value)['role_id'])&.name if log.old_value.present?

        member = Member.find_by(id: JSON.parse(log.old_value)['member_id']) if log.old_value.present?
      else
        "Unknown Activity"
      end
    else
      "Unknown Entity"
    end
  end

  def fetch_author_name(log)
    author = User.find_by(id: log.author_id)
    "#{author&.firstname} #{author&.lastname}" || "Unknown Author"
  end

  def format_log_message(log)
    author_name = fetch_author_name(log)
    entity_name = fetch_entity_name(log)
    timestamp = log.created_at.in_time_zone("Asia/Kolkata").strftime("%d/%m/%Y %H:%M")

    case log.field_name
    when 'Create'
      "Created: #{log.entity_type} #{entity_name} <em>created by</em> <strong>#{author_name}</strong>"
    when 'Delete'
      "Deleted: #{log.entity_type} #{entity_name} <em>deleted by</em> <strong>#{author_name}</strong>"
    else
      "Updated: : <strong>#{log.field_name}</strong> <em>changed from</em> '#{log.old_value}' <em>to</em> '#{log.new_value}' #{log.entity_type} #{entity_name} <em>updated by</em> <strong>#{author_name}</strong>"
    end.html_safe
  end

  def created_message(new_value, author_id, created_at)
    format_message("created", new_value, author_id, created_at)
  end

  def updated_message(log, values, author_id, updated_at)
    update_format_message("updated", log, values, author_id, updated_at)
  end

  def deleted_message(old_value, author_id, deleted_at)
    format_message("deleted", old_value, author_id, deleted_at)
  end

  def update_format_message(action, log, values, author_id, updated_at)
    action_text = "#{action.capitalize}d"

    issue = Issue.find_by(id: log.entity_id)  # Fetch the issue corresponding to the log

    if issue.present?
      subject = issue.subject
      id = issue.id
      tracker_name = issue.tracker.name
      project_name = issue.project.name
    else
      issue = ActivityLog.find_by(entity_id: log.entity_id, field_name: "Create") ||ActivityLog.find_by(entity_id: log.entity_id, field_name: "Delete")

      if issue.old_value.nil?
        json_data = JSON.parse(issue.new_value)
      else
        json_data = JSON.parse(issue.old_value)
      end
      subject = json_data['subject']
      id = json_data['id']
      tracker_name = json_data.dig('tracker', 'name')
      project_name = json_data.dig('project', 'name')
    end
    "ID: <b>#{id}</b>, <i>Subject</i> <b>#{subject}</b>, <i>Tracker</i> <b>#{tracker_name}</b>, <i>Project</i> <b>#{project_name}</b>"
  end

  def format_message(action, data, author_id, timestamp)
    action_text = "#{action.capitalize}d"
    issue_details(data).to_s if data.present?
  end

  def issue_details(data)
    if data.is_a?(String)
      json_data = JSON.parse(data)
      subject = json_data['subject']
      id = json_data['id']
      tracker_name = json_data.dig('tracker', 'name')
      project_name = json_data.dig('project', 'name')
      "ID: <b>#{id}</b>, <i>Subject</i> <b>#{subject}</b>, <i>Tracker</i> <b>#{tracker_name}</b>, <i>Project</i> <b>#{project_name}</b>"
    end
  rescue JSON::ParserError => e
    Rails.logger.error "JSON parsing error: #{e.message}"
    "Invalid JSON data"
  end
end
