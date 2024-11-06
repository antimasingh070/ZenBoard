class Point < ActiveRecord::Base
    belongs_to :mom
    has_many :remarks, dependent: :destroy
  
    validates :description, presence: true
    # validates :status, presence: true
    STATUS_APPROVED     = 1
    STATUS_REJECTED     = 2
    STATUS_PENDING = 3
    STATUS_OPEN = 4
    STATUS_IN_PROGRESS = 5
    STATUS_CLOSE = 6

    STATUS_MAP = {
        STATUS_APPROVED => 'Approved',
        STATUS_REJECTED => 'Declined',
        STATUS_PENDING => 'Pending',
        STATUS_OPEN => 'Open',
        STATUS_IN_PROGRESS => 'In Progress',
        STATUS_CLOSE => 'Close'
    }.freeze

    def approved?
        self.status == 1
    end
    
    def rejected?
        self.status == 2
    end

end