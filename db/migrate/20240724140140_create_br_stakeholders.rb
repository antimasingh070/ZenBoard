class CreateBrStakeholders < ActiveRecord::Migration[6.1]
  def change
    create_table :br_stakeholders do |t|
      t.bigint :business_requirement_id, null: false  # Keep as bigint if `business_requirements.id` is bigint
      t.integer :user_id, null: false  # Change to integer to match `users.id`
      t.integer :role_id, null: false
      t.timestamps
    end
  end
end
