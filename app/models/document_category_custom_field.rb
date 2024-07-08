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

class DocumentCategoryCustomField < CustomField

  after_create :log_create_activity
  after_update :log_update_activity
  after_destroy :log_destroy_activity

  def log_create_activity
    ActivityLog.create(
      entity_type: 'DocumentCategoryCustomField',
      entity_id: self.id,
      field_name: 'Create',
      old_value: nil,
      new_value: document_category_custom_field_details.to_json,
      author_id: User.current.id
    )
  end

  def log_update_activity
    saved_changes.except('updated_on').each do |field_name, values|
      old_value = values[0].to_s
      new_value = values[1].to_s

      case field_name
      when 'document_category_id'
        old_value = DocumentCategory.find_by(id: values[0])&.name if values[0].present?
        new_value = DocumentCategory.find_by(id: values[1])&.name if values[1].present?
      when 'custom_field_id'
        old_value = CustomField.find_by(id: values[0])&.name if values[0].present?
        new_value = CustomField.find_by(id: values[1])&.name if values[1].present?
      end

      ActivityLog.create(
        entity_type: 'DocumentCategoryCustomField',
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
      entity_type: 'DocumentCategoryCustomField',
      entity_id: self.id,
      field_name: 'Delete',
      old_value: document_category_custom_field_details.to_json,
      new_value: nil,
      author_id: User.current.id
    )
  end

  def document_category_custom_field_details
    {
      id: self.id,
      document_category: document_category_detail,
      custom_field: custom_field_detail
    }
  end

  def document_category_detail
    { id: self.document_category_id, name: DocumentCategory.find_by(id: self.document_category_id)&.name }
  end

  def custom_field_detail
    { id: self.custom_field_id, name: CustomField.find_by(id: self.custom_field_id)&.name }
  end

  def type_name
    :enumeration_doc_categories
  end
end
