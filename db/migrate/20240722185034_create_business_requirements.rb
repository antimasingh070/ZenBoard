class CreateBusinessRequirements < ActiveRecord::Migration[6.1]
  def change
    create_table :business_requirements do |t|
      t.string :requirement_case
      t.string :identifier, null: false, unique: true
      t.text :description
      t.string :cost_benefits
      t.integer :status
      t.string :project_identifier
      t.string :project_sponsor
      t.date :requirement_submitted_date
      t.date :scheduled_end_date
      t.date :actual_start_date
      t.date :actual_end_date
      t.date :revised_end_date
      t.text :business_need_as_per_business_case
      t.date :planned_project_go_live_date
      t.boolean :is_it_project
      t.string :project_category
      t.string :vendor_name
      t.string :priority_level
      t.string :project_enhancement
      t.string :template

      t.timestamps
    end
  end
end
