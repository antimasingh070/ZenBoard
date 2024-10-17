class CreateMoms < ActiveRecord::Migration[6.1]
  def change
    create_table :moms do |t|
      t.references :meeting, null: false, foreign_key: true  # MOM associated with a meeting
      t.text :summary  # Summary of MOM
      t.integer :status
      t.string :function_name
      t.date :target_date

      t.timestamps
    end
  end
end