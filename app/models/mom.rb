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
end
  