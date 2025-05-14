# frozen_string_literal: true

class BusinessRequirement< ActiveRecord::Base
  include Redmine::SafeAttributes
  serialize :portfolio_category
  serialize :requirement_received_from
  serialize :application_name
  # Project statuses
  STATUS_IN_DISCUSSION = 1
  STATUS_REQUIREMENT_FINILIZED = 2
  STATUS_AWAITING_DETAILS = 3
  STATUS_AWATING_BUSINESS_CASE = 4
  STATUS_REQUIREMENT_NOT_APPROVED = 5
  STATUS_REQUIREMENT_ON_HOLD = 6
  STATUS_ACCEPTED = 7
  STATUS_CANCELLED = 8
  STATUS_CLOSED = 9

  STATUS_MAP = {
    STATUS_IN_DISCUSSION => 'In Discussion',
      STATUS_REQUIREMENT_FINILIZED => 'Requirement Finalized',
      STATUS_AWAITING_DETAILS => 'Awaiting Details',
      STATUS_AWATING_BUSINESS_CASE => 'Awaiting Business Case',
      STATUS_REQUIREMENT_NOT_APPROVED => 'Requirement Not Approved',
      STATUS_REQUIREMENT_ON_HOLD => 'Requirement On Hold',
      STATUS_ACCEPTED => 'Accepted',
      STATUS_CANCELLED   => 'Cancelled',
      STATUS_CLOSED => 'Closed'
  }.freeze

  IDENTIFIER_MAX_LENGTH = 50
  has_many :br_stakeholders, dependent: :destroy
  has_many :status_logs, dependent: :destroy
  has_many :attachments, as: :container, dependent: :destroy
  accepts_nested_attributes_for :attachments, allow_destroy: true

  accepts_nested_attributes_for :br_stakeholders, allow_destroy: true
  has_many :users, through: :br_stakeholders
  # Add other associations and validations as needed
  # has_many :attachments, as: :container
  has_many :meetings, dependent: :destroy
  has_many :moms, through: :meetings

  accepts_nested_attributes_for :meetings, allow_destroy: true
  accepts_nested_attributes_for :moms, allow_destroy: true

  validates :requirement_case, :description, presence: true
  validates :identifier, uniqueness: true, on: :update
  after_create :set_identifier_from_id
  safe_attributes 'requirement_case', 'identifier', 'description', 'cost_benefits', 'status',
                  'project_sponsor', 'scheduled_start_date', 'scheduled_end_date',
                  'actual_start_date', 'actual_end_date', 'revised_end_date',
                  'business_need', 'planned_project_go_live_date', 'is_it_project',
                  'project_category', 'vendor_name', 'priority_level', 'project_enhancement',
                   'template', 'portfolio_category', 'requirement_received_from', 'application_name'

  after_create :log_create_activity
  after_update :log_update_activity
  after_destroy :log_destroy_activity

  after_save:add_pmo_and_tsg

  def add_pmo_and_tsg
    group_names = %w[PMO TSG]

    group_names.each do |group_name|
      group = Group.find_by(lastname: group_name)
      next unless group

      user_ids = group.users.where(status: 1).pluck(:id)
      role = Role.find_by(name: group_name)
      next unless role

      user_ids.each do |user_id|
        BrStakeholder.find_or_create_by(
          user_id: user_id,
          role_id: role.id,
          business_requirement_id: id
        )
      end
    end

    Mailer.deliver_business_requirement_created(User.current, stakeholders.pluck(:user_id), self)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Role or Group not found: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Error in add_pmo_and_tsg: #{e.message}"
  end

  def has_stakeholders?
    br_stakeholders.any?
  end

  def log_create_activity
    activity_log = ActivityLog.create(
      entity_type: 'BusinessRequirement',
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
        entity_type: 'BusinessRequirement',
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
      entity_type: 'BusinessRequirement',
      entity_id: self.id,
      field_name: 'Delete',
      old_value: self.attributes.to_json,
      new_value: nil,
      author_id: User.current.id
    )
  end

  def attributes_editable?(user=User.current)
  end

  def attachments_editable?(user=User.current)
    attributes_editable?(user)
  end

  def deletable?(user=User.current)
  end

  # Overrides Redmine::Acts::Attachable::InstanceMethods#attachments_deletable?
  def attachments_deletable?(user=User.current)
    attributes_editable?(user)
  end

  def set_identifier_from_id
    update_column(:identifier, "BR_#{id}")
  end
end
