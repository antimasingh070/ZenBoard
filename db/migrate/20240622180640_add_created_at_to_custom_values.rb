class AddCreatedAtToCustomValues < ActiveRecord::Migration[6.1]
  def change
    add_column :custom_values, :created_at, :datetime
  end
end
