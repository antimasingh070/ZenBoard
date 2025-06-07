class AddBusinessBenefitFieldsToBusinessRequirements < ActiveRecord::Migration[6.1]
  def change
    add_column :business_requirements, :business_benefit_categories, :string
    add_column :business_requirements, :business_benefit_data, :json
  end
end
