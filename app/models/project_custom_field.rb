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

class ProjectCustomField < CustomField
  after_create :log_create_activity
  after_update :log_update_activity
  after_destroy :log_destroy_activity


  def log_create_activity
    activity_log = ActivityLog.create(
      entity_type: 'ProjectCustomField',
      entity_id: self.id,
      field_name: 'Create',
      old_value: nil,
      new_value: self.attributes.to_json,
      author_id: User.current.id
    )
  end
  # changes_hash
  def log_update_activity
    saved_changes.each do |field_name, values|
      ActivityLog.create(
        entity_type: 'ProjectCustomField',
        entity_id: self.id,
        field_name: field_name,
        old_value: values[0].to_s,
        new_value: values[1].to_s,
        author_id: User.current.id
      )
    end
  end

  def log_destroy_activity
    activity_log = ActivityLog.create(
      entity_type: 'ProjectCustomField',
      entity_id: self.id,
      field_name: 'Delete',
      old_value: self.attributes.to_json,
      new_value: nil,
      author_id: User.current.id
    )
  end

  def type_name
    :label_project_plural
  end

  def visible_by?(project, user=User.current)
    super || (roles & user.roles_for_project(project)).present?
  end

  def visibility_by_project_condition(project_key=nil, user=User.current, id_column=nil)
    project_key ||= "#{Project.table_name}.id"
    super(project_key, user, id_column)
  end
end
