class AlterPointsToStoreMultipleOwners < ActiveRecord::Migration[6.1]
  def change
    change_column :points, :owner, :string, array: true, default: '{}'
  end
end
