class CreateActivityLogs < ActiveRecord::Migration[6.1]
  def change
    create_table :activity_logs do |t|
      t.string :entity_type
      t.integer :entity_id
      t.string :field_name
      t.text :old_value
      t.text :new_value
      t.integer :author_id

      t.timestamps
    end
  end
end
