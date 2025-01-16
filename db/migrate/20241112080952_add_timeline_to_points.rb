class AddTimelineToPoints < ActiveRecord::Migration[6.1]
  def change
    add_column :points, :timeline, :date
  end
end
