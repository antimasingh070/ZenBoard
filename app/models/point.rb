class Point < ActiveRecord::Base
    belongs_to :mom
    has_many :remarks, dependent: :destroy
  
    validates :description, presence: true
    # validates :status, presence: true
    STATUS_APPROVED     = 1
    STATUS_REJECTED     = 2
    
    STATUS_MAP = {
        STATUS_APPROVED => 'Approved',
        STATUS_REJECTED => 'Rejected'
    }.freeze

    def approved?
        self.status == 1
    end
    
    def rejected?
        self.status == 2
    end

end