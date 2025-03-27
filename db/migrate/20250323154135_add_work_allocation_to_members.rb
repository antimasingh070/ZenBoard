class AddWorkAllocationToMembers < ActiveRecord::Migration[6.1]
  def change
    add_column :members, :work_allocation, :integer, null: true
  end
end
