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

class CustomFieldEnumeration < ActiveRecord::Base
  belongs_to :custom_field

  validates_presence_of :name, :position, :custom_field_id
  validates_length_of :name, :maximum => 60
  validates_numericality_of :position, :only_integer => true
  before_create :set_position

  scope :active, lambda {where(:active => true)}

  after_create :log_create_activity
  after_update :log_update_activity
  after_destroy :log_destroy_activity

  def log_create_activity
    ActivityLog.create(
      entity_type: 'CustomFieldEnumeration',
      entity_id: self.id,
      field_name: 'Create',
      old_value: nil,
      new_value: custom_field_enumeration_details.to_json,
      author_id: User.current.id
    )
  end

  def log_update_activity
    saved_changes.except('updated_on').each do |field_name, values|
      old_value = values[0].to_s
      new_value = values[1].to_s

      case field_name
      when 'custom_field_id'
        old_value = CustomField.find_by(id: values[0])&.name if values[0].present?
        new_value = CustomField.find_by(id: values[1])&.name if values[1].present?
      end

      ActivityLog.create(
        entity_type: 'CustomFieldEnumeration',
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
      entity_type: 'CustomFieldEnumeration',
      entity_id: self.id,
      field_name: 'Delete',
      old_value: custom_field_enumeration_details.to_json,
      new_value: nil,
      author_id: User.current.id
    )
  end

  def custom_field_enumeration_details
    {
      id: self.id,
      custom_field: custom_field_detail,
      name: self.name,
      active: self.active,
      position: self.position
    }
  end

  def custom_field_detail
    { id: self.custom_field_id, name: CustomField.find_by(id: self.custom_field_id)&.name }
  end

  def to_s
    name.to_s
  end

  def objects_count
    custom_values.count
  end

  def in_use?
    objects_count > 0
  end

  alias :destroy_without_reassign :destroy
  def destroy(reassign_to=nil)
    if reassign_to
      custom_values.update_all(:value => reassign_to.id.to_s)
    end
    destroy_without_reassign
  end

  def custom_values
    custom_field.custom_values.where(:value => id.to_s)
  end

  def self.update_each(custom_field, attributes)
    transaction do
      attributes.each do |enumeration_id, enumeration_attributes|
        enumeration = custom_field.enumerations.find_by_id(enumeration_id)
        if enumeration
          if block_given?
            yield enumeration, enumeration_attributes
          else
            enumeration.attributes = enumeration_attributes
          end
          unless enumeration.save
            raise ActiveRecord::Rollback
          end
        end
      end
    end
  end

  def self.fields_for_order_statement(table=nil)
    table ||= table_name
    columns = ['position']
    columns.uniq.map {|field| "#{table}.#{field}"}
  end

  private

  def set_position
    max = self.class.where(:custom_field_id => custom_field_id).maximum(:position) || 0
    self.position = max + 1
  end
end
