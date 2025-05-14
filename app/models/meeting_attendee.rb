# frozen_string_literal: true

class MeetingAttendee < ActiveRecord::Base
  belongs_to :meeting
  belongs_to :user
  belongs_to :role
  # Add other associations and validations as needed
end
