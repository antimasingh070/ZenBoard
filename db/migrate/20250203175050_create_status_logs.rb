class CreateStatusLogs < ActiveRecord::Migration[6.1]
  def change
    create_table :status_logs do |t|
      t.references :business_requirement, foreign_key: true
      t.integer :status
      t.string :updated_by
      t.text :reason

      t.timestamps
    end
  end
end
