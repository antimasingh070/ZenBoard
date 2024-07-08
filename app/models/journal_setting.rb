class JournalSetting < ActiveRecord::Base
    belongs_to :user
  
    # Add any other necessary associations and validations
    belongs_to :journalized, polymorphic: true

    serialize :value_changes, Hash

  # Add this line
  attribute :journalized_entry_type, :string
  end
  