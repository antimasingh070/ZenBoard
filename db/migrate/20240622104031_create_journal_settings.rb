class CreateJournalSettings < ActiveRecord::Migration[6.1]
  def change
    create_table :journal_settings do |t|
      t.integer :user_id, null: false
      t.string :name
      t.datetime :created_on

      t.timestamps
    end

    add_foreign_key :journal_settings, :users, column: :user_id
    add_index :journal_settings, :user_id
  end
end
