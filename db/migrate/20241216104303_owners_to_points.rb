class OwnersToPoints < ActiveRecord::Migration[6.1]
  def change
    add_column :points, :owner_ids, :string, array: true, default: '{}'
  end
end
