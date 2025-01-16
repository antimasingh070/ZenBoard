class CreateRemarks < ActiveRecord::Migration[6.1]
  def change
    create_table :remarks do |t|
      t.references :point, null: false, foreign_key: true  # Remarks associated with a point
      t.text :content
      t.integer :author_id
      
      t.timestamps
    end
  end
end
