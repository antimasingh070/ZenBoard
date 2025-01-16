class BrStakeholder < ActiveRecord::Base
    belongs_to :business_requirement
    belongs_to :user
    belongs_to :role
    validates :user_id, presence: true

end
  