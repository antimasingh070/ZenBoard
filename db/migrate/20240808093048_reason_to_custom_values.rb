class ReasonToCustomValues < ActiveRecord::Migration[6.1]
  def change
    add_column :custom_values, :reason, :text
    add_column :custom_values, :author_id, :integer
  end
end
