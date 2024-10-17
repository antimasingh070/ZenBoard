class BusinessRequirement< ActiveRecord::Base
    include Redmine::SafeAttributes
    serialize :portfolio_category
    serialize :requirement_received_from
    serialize :application_name
    # Project statuses
    STATUS_IN_DISCUSSION     = 1
    STATUS_REQUIREMENT_FINILIZED     = 2
    STATUS_AWAITING_DETAILS = 3
    STATUS_AWATING_BUSINESS_CASE = 4
    STATUS_REQUIREMENT_NOT_APPROVED = 5
    STATUS_REQUIREMENT_ON_HOLD = 6
    STATUS_ACCEPTED = 7
    STATUS_CANCELLED   = 8
    STATUS_CLOSED = 9
    
    STATUS_MAP = {
        STATUS_IN_DISCUSSION => 'In Discussion',
        STATUS_REQUIREMENT_FINILIZED => 'Requirement Finilized',
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

    validates :requirement_case, :identifier, :description, presence: true
    validates :identifier, uniqueness: true
    before_validation :set_unique_identifier, on: [:create, :new]
    safe_attributes 'requirement_case', 'identifier', 'description', 'cost_benefits', 'status',
                    'project_sponsor', 'scheduled_start_date', 'scheduled_end_date',
                    'actual_start_date', 'actual_end_date', 'revised_end_date',
                    'business_need', 'planned_project_go_live_date', 'is_it_project', 
                    'project_category', 'vendor_name', 'priority_level', 'project_enhancement',
                     'template','portfolio_category', 'requirement_received_from', 'application_name'

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

    def set_unique_identifier
        # return if self.identifier.present? && !self.identifier_changed?

        # Generate a unique identifier for new records
        max_id = BusinessRequirement&.last&.id || 0
        self.identifier = "BR_#{max_id + 1}"
    end
end
  