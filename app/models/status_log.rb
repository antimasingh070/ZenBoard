# frozen_string_literal: true

class StatusLog < ActiveRecord::Base
  belongs_to :business_requirement
end
