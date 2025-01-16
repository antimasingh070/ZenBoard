class CreatePoints < ActiveRecord::Migration[6.1]
  def change
    create_table :points do |t|
      t.references :mom, null: false, foreign_key: true  # Points associated with MOM
      t.text :description
      t.integer :status
      
      t.timestamps
    end
  end
end
