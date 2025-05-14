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

class WorkflowPermission < WorkflowRule
  validates_inclusion_of :rule, :in => %w(readonly required)
  validates_presence_of :old_status
  validate :validate_field_name

  after_create :log_create_activity
  after_update :log_update_activity
  after_destroy :log_destroy_activity

  def log_create_activity
    ActivityLog.create(
      entity_type: 'WorkflowPermission',
      entity_id: self.id,
      field_name: 'Create',
      old_value: nil,
      new_value: workflow_permission_details.to_json,
      author_id: User.current.id
    )
  end

  def log_update_activity
    saved_changes.each do |field_name, values|
      old_value = values[0].to_s
      new_value = values[1].to_s

      case field_name
      when 'role_id'
        old_value = Role.find_by(id: values[0])&.name if values[0].present?
        new_value = Role.find_by(id: values[1])&.name if values[1].present?
      when 'tracker_id'
        old_value = Tracker.find_by(id: values[0])&.name if values[0].present?
        new_value = Tracker.find_by(id: values[1])&.name if values[1].present?
      end

      ActivityLog.create(
        entity_type: 'WorkflowPermission',
        entity_id: self.id,
        field_name: field_name,
        old_value: old_value,
        new_value: new_value,
        author_id: User.current.id
      )
    end
  end

  def log_destroy_activity
    ActivityLog.create(
      entity_type: 'WorkflowPermission',
      entity_id: self.id,
      field_name: 'Delete',
      old_value: workflow_permission_details.to_json,
      new_value: nil,
      author_id: User.current.id
    )
  end

  def workflow_permission_details
    {
      id: self.id,
      role: role_detail,
      tracker: tracker_detail,
      field_name: self.field_name
    }
  end

  def role_detail
    { id: self.role_id, name: Role.find_by(id: self.role_id)&.name }
  end

  def tracker_detail
    { id: self.tracker_id, name: Tracker.find_by(id: self.tracker_id)&.name }
  end

  # Returns the workflow permissions for the given trackers and roles
  # grouped by status_id
  #
  # Example:
  #   WorkflowPermission.rules_by_status_id trackers, roles
  #   # => {1 => {'start_date' => 'required', 'due_date' => 'readonly'}}
  def self.rules_by_status_id(trackers, roles)
    WorkflowPermission.where(:tracker_id => trackers.map(&:id), :role_id => roles.map(&:id)).inject({}) do |h, w|
      h[w.old_status_id] ||= {}
      h[w.old_status_id][w.field_name] ||= []
      h[w.old_status_id][w.field_name] << w.rule
      h
    end
  end

  # Replaces the workflow permissions for the given trackers and roles
  #
  # Example:
  #   WorkflowPermission.replace_permissions trackers, roles, {'1' => {'start_date' => 'required', 'due_date' => 'readonly'}}
  def self.replace_permissions(trackers, roles, permissions)
    trackers = Array.wrap trackers
    roles = Array.wrap roles

    transaction do
      permissions.each do |status_id, rule_by_field|
        rule_by_field.each do |field, rule|
          where(:tracker_id => trackers.map(&:id), :role_id => roles.map(&:id), :old_status_id => status_id, :field_name => field).destroy_all
          if rule.present?
            trackers.each do |tracker|
              roles.each do |role|
                WorkflowPermission.create(:role_id => role.id, :tracker_id => tracker.id, :old_status_id => status_id, :field_name => field, :rule => rule)
              end
            end
          end
        end
      end
    end
  end

  protected

  def validate_field_name
    unless Tracker::CORE_FIELDS_ALL.include?(field_name) || /^\d+$/.match?(field_name.to_s)
      errors.add :field_name, :invalid
    end
  end
end
