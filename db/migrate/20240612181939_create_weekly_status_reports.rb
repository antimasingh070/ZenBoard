class CreateWeeklyStatusReports < ActiveRecord::Migration[6.1]
  def change
    create_table :weekly_status_reports do |t|
      t.date :report_date

      t.timestamps
    end
  end
end
