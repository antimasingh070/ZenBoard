class AuthorIdToProjects < ActiveRecord::Migration[6.1]
  def change
    add_column :projects, :author_id, :integer
    add_index :projects, :author_id
  end
end
