class CreateMeetings < ActiveRecord::Migration[6.1]
  def change
    create_table :meetings do |t|
      t.references :business_requirement, null: false, foreign_key: true
      t.string :title
      t.datetime :scheduled_at
      t.integer :status
      t.string :function_name
      t.text :note

      t.timestamps
    end
  end
end
