class AssigneeToPoints < ActiveRecord::Migration[6.1]
  def change
    add_column :points, :owner, :integer, array: true, default: []
  end
end
