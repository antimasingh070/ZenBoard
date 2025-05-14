# frozen_string_literal: true

class ActivityLog < ActiveRecord::Base
  validates :entity_type, :entity_id, :field_name, :author_id, presence: true
end
