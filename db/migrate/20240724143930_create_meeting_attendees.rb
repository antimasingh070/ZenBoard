class CreateMeetingAttendees < ActiveRecord::Migration[6.1]
  def change
    create_table :meeting_attendees do |t|
      t.bigint :meeting_id, null: false  # Change to integer if `meetings.id` is integer
      t.integer :user_id, null: false 

      t.timestamps
    end  
  end
end
