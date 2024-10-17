class Meeting < ActiveRecord::Base
    belongs_to :business_requirement
    has_one :mom, dependent: :destroy
    has_many :meeting_attendees, dependent: :destroy
    accepts_nested_attributes_for :meeting_attendees, allow_destroy: true
    validates :title, :scheduled_at, :status, presence: true
    STATUS_APPROVED     = 1
    STATUS_REJECTED     = 5
    STATUS_IN_PROGRESS   = 9
    STATUS_CLOSED = 10
    
    STATUS_MAP = {
        STATUS_IN_PROGRESS   => 'In Progress',
        STATUS_APPROVED => 'Approved',
        STATUS_REJECTED => 'Rejected',
        STATUS_CLOSED => 'Closed'
    }.freeze
    # Add other associations and validations as needed
    validates :title, :scheduled_at, :status, :note, presence: true
    after_save :send_invites

    def send_invites
      self.meeting_attendees.each do |attendee|
        user = User.first
        Mailer.deliver_meeting_invitation(user, self)
      end
    end
  
end
  