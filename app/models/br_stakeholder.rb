# frozen_string_literal: true

class BrStakeholder < ActiveRecord::Base
  belongs_to :business_requirement
  belongs_to :user
  belongs_to :role

  after_create :add_to_project_members
  after_destroy :remove_from_project_members

  def add_to_project_members
    project = Project.find_by(identifier: self.business_requirement.project_identifier)
    return unless project

    # Avoid duplicate entry
    member = Member.find_or_initialize_by(user_id: self.user_id, project_id: project.id)
    if member.new_record?
      member.roles = [Role.find(self.role_id)]
      member.save!
    end
    if member.persisted?
      # Associate the member with the role
      MemberRole.find_or_create_by(member_id: member.id, role_id: self.role_id, inherited_from: nil)
    end
  end

  def remove_from_project_members
    project = Project.find_by(identifier: self.business_requirement.project_identifier)
    return unless project

    member = Member.find_by(
      project_id: project.id,
        user_id: self.user_id
    )
    member_role = MemberRole.find_by(member_id: member.id, role_id: self.role_id, inherited_from: nil)
    member&.destroy
  end
end
