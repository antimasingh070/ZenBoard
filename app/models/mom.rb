class Mom < ActiveRecord::Base
    belongs_to :meeting
    has_many :points, dependent: :destroy
  
    STATUS_IN_PROGRESS   = 9
    STATUS_APPROVED     = 1
    STATUS_REJECTED     = 5
    STATUS_CLOSED = 10
    
    STATUS_MAP = {
        STATUS_IN_PROGRESS   => 'In Progress',
        STATUS_APPROVED => 'Approved',
        STATUS_REJECTED => 'Rejected',
        STATUS_CLOSED => 'Closed'
    }.freeze
    # Add other associations and validations as needed

    after_create :log_create_activity
    after_update :log_update_activity
    after_destroy :log_destroy_activity

    def log_create_activity
        activity_log = ActivityLog.create(
        entity_type: 'Mom',
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
            entity_type: 'Mom',
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
        entity_type: 'Mom',
        entity_id: self.id,
        field_name: 'Delete',
        old_value: self.attributes.to_json,
        new_value: nil,
        author_id: User.current.id
        )
    end
end
  