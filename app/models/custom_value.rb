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

class CustomValue < ActiveRecord::Base
  belongs_to :custom_field
  belongs_to :customized, :polymorphic => true
  before_update :log_custom_field_changes
  after_save :custom_field_after_save_custom_value
  validates :reason, length: { maximum: 100, tokenizer: ->(str) { str.scan(/\w+/) }, too_long: "is limited to %{count} words" }
  after_create :log_create_activity
  after_update :log_update_activity
  after_destroy :log_destroy_activity


  def log_create_activity
    activity_log = ActivityLog.create(
      entity_type: 'CustomValue',
      entity_id: self.id,
      field_name: 'Create',
      old_value: custom_value_details.to_json,
      new_value: nil,
      author_id: User.current.id
    )
  end

  # changes_hash
  def log_update_activity
    saved_changes.each do |field_name, values|
      old_value = values[0].to_s
      new_value = values[1].to_s
  
      # Handle specific field conversions if needed
      case field_name
      when 'custom_field_id'
        old_value = CustomField.find_by(id: values[0])&.name if values[0].present?
        new_value = CustomField.find_by(id: values[1])&.name if values[1].present?
      end
  
      # Create ActivityLog entry
      ActivityLog.create(
        entity_type: 'CustomValue',
        entity_id: self.id,
        field_name: field_name,
        old_value: old_value,
        new_value: new_value,
        author_id: User.current.id
      )
    end
  end  

  def log_destroy_activity
    activity_log = ActivityLog.create(
      entity_type: 'CustomValue',
      entity_id: self.id,
      field_name: 'Delete',
      old_value: custom_value_details.to_json,
      new_value: nil,
      author_id: User.current.id
    )
  end

  def custom_value_details
    {
      id: self.id,
      custom_field: custom_field_detail,
      value: self.value,
      customized: customized_detail,
      created_on: self.created_at
    }
  end

  def custom_field_detail
    { id: self.custom_field_id, name: CustomField.find_by(id: self.custom_field_id)&.name }
  end

  def customized_detail
    case self.customized_type
    when 'Issue'
      issue = Issue.find_by(id: self.customized_id)
      { id: issue&.id, subject: issue&.subject }
    when 'Project'
      project = Project.find_by(id: self.customized_id)
      { id: project&.id, name: project&.name }
    when 'TimeEntry'
      time_entry = TimeEntry.find_by(id: self.customized_id)
      { id: time_entry&.id, hours: time_entry&.hours }
    when 'User'
      user = User.find_by(id: self.customized_id)
      { id: user&.id, name: user&.firstname }
    when 'Group'
      group = Group.find_by(id: self.customized_id)
      { id: group&.id, name: group&.lastname }
    when 'Document'
      document = Document.find_by(id: self.customized_id)
      { id: document&.id, title: document&.title }
    when 'Version'
      version = Version.find_by(id: self.customized_id)
      { id: version&.id, name: version&.name }
    when 'News'
      news = News.find_by(id: self.customized_id)
      { id: news&.id, title: news&.title }
    when 'WikiPage'
      wiki_page = WikiPage.find_by(id: self.customized_id)
      { id: wiki_page&.id, title: wiki_page&.title }
    when 'Repository'
      repository = Repository.find_by(id: self.customized_id)
      { id: repository&.id, name: repository&.name }
    else
      { id: self.customized_id, type: self.customized_type }
    end
  end
  
  def initialize(attributes=nil, *args)
    super
    if new_record? && custom_field && !attributes.key?(:value) && (customized.nil? || customized.set_custom_field_default?(self))
      self.value ||= custom_field.default_value
    end
  end

  # Returns true if the boolean custom value is true
  def true?
    self.value == '1'
  end

  def editable?
    custom_field.editable?
  end

  def visible?(user=User.current)
    if custom_field.visible?
      true
    elsif customized.respond_to?(:project)
      custom_field.visible_by?(customized.project, user)
    else
      false
    end
  end

  def attachments_visible?(user)
    visible?(user) && customized && customized.visible?(user)
  end

  def required?
    custom_field.is_required?
  end

  def to_s
    value.to_s
  end

  private

  def log_custom_field_changes
    changes.each do |attribute, values|
      old_value, new_value = values
      Rails.logger.info "Custom field #{self.custom_field.name} (ID: #{self.custom_field.id}) for #{self.customized_type} (ID: #{self.customized_id}): #{attribute} changed from #{old_value} to #{new_value}"
    end
  end

  def custom_field_after_save_custom_value
    custom_field.after_save_custom_value(self)
  end
end
