class Remark < ActiveRecord::Base
    belongs_to :point
    belongs_to :author, class_name: 'User'  # Assuming you have a User model for authors
  
    validates :content, presence: true
end