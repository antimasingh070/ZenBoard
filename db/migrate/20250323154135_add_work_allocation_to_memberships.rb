class AddWorkAllocationToMemberships < ActiveRecord::Migration[6.1]
  def change
    add_column :memberships, :work_allocation, :string
  end
end
