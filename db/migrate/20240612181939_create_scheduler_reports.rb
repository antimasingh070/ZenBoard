class CreateSchedulerReports < ActiveRecord::Migration[6.1]
  def change
    create_table :scheduler_reports do |t|
      t.date :report_date, null: false
      t.integer :project_id
      t.string :report_type
      t.timestamps
    end
  end
end
