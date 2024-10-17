class MeetingAttendee < ActiveRecord::Base
    belongs_to :meeting
    belongs_to :user
    belongs_to :role
    validates :user_id, presence: true
    # Add other associations and validations as needed
end

  