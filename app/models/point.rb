# frozen_string_literal: true

class Point < ActiveRecord::Base
  serialize :owner_ids, Array
  belongs_to :mom
  has_many :remarks, dependent: :destroy

  validates :description, :timeline, presence: true
  # validates :status, presence: true
  STATUS_APPROVED     = 1
  STATUS_REJECTED     = 2
  STATUS_PENDING = 3
  STATUS_OPEN = 4
  STATUS_IN_PROGRESS = 5
  STATUS_CLOSE = 6

  STATUS_MAP = {
    STATUS_OPEN => 'Open',
      STATUS_IN_PROGRESS => 'In Progress',
      STATUS_PENDING => 'Pending',
      STATUS_APPROVED => 'Approved',
      STATUS_REJECTED => 'Declined',
      STATUS_CLOSE => 'Close'
  }.freeze

  after_create :log_create_activity
  after_update :log_update_activity
  after_destroy :log_destroy_activity

  def log_create_activity
    activity_log = ActivityLog.create(
      entity_type: 'Point',
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
        entity_type: 'Point',
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
      entity_type: 'Point',
      entity_id: self.id,
      field_name: 'Delete',
      old_value: self.attributes.to_json,
      new_value: nil,
      author_id: User.current.id
    )
  end

  def approved?
    self.status == 1
  end

  def rejected?
    self.status == 2
  end
end
