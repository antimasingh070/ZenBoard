# frozen_string_literal: true

class Remark < ActiveRecord::Base
  belongs_to :point
  belongs_to :author, class_name: 'User'  # Assuming you have a User model for authors

  validates :content, presence: true

  after_create :log_create_activity
  after_update :log_update_activity
  after_destroy :log_destroy_activity

  def log_create_activity
    activity_log = ActivityLog.create(
      entity_type: 'Remark',
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
        entity_type: 'Remark',
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
      entity_type: 'Remark',
      entity_id: self.id,
      field_name: 'Delete',
      old_value: self.attributes.to_json,
      new_value: nil,
      author_id: User.current.id
    )
  end
end
