class AddArrayColumnToBusinessRequirements < ActiveRecord::Migration[6.1]
  def change
    add_column :business_requirements, :portfolio_category, :string, array: true, default: '{}'
    add_column :business_requirements, :requirement_received_from, :string, array: true, default: '{}'
    add_column :business_requirements, :application_name, :string, array: true, default: '{}'
  end
end
