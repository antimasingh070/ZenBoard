# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2023  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class MemberRole < ActiveRecord::Base
  belongs_to :member
  belongs_to :role

  after_destroy :remove_member_if_empty

  after_create :add_role_to_group_users, :add_role_to_subprojects
  after_destroy :remove_inherited_roles

  validates_presence_of :role
  validate :validate_role_member

  after_create :log_create_activity
  after_update :log_update_activity
  after_destroy :log_destroy_activity

  def log_create_activity
    ActivityLog.create(
      entity_type: 'MemberRole',
      entity_id: self.id,
      field_name: 'Create',
      old_value: nil,
      new_value: member_role_details.to_json,
      author_id: User.current.id
    )
  end

  def log_update_activity
    if saved_changes.any?
      saved_changes.each do |field_name, values|
        old_value = values[0].to_s
        new_value = values[1].to_s
        case field_name
        when 'role_id'
          old_role_name = Role.find_by(id: old_value)&.name || 'Unknown Role'
          new_role_name = Role.find_by(id: new_value)&.name || 'Unknown Role'
          message = "Role changed from '#{old_role_name}' to '#{new_role_name}'"
        # Add more cases for other fields if needed
        else
          message = "#{field_name} changed from '#{old_value}' to '#{new_value}'"
        end
        ActivityLog.create(
          entity_type: 'MemberRole',
          entity_id: self.id,
          field_name: field_name,
          old_value: old_value,
          new_value: new_value,
          message: message,
          author_id: User.current.id
        )
      end
    end
  end

  def log_destroy_activity
    ActivityLog.create(
      entity_type: 'MemberRole',
      entity_id: self.id,
      field_name: 'Delete',
      old_value: member_role_details.to_json,
      new_value: nil,
      author_id: User.current.id
    )
  end

  def member_role_details
    {
      id: self.id,
      member: member_detail,
      role: role_detail
    }
  end

  def member_detail
    {
      id: self.member_id,
      project: project_detail,
      user: user_detail(self.member.user_id)
    }
  end

  def project_detail
    { id: self.member.project_id, name: Project.find_by(id: self.member.project_id)&.name }
  end

  def user_detail(user_id)
    user = User.find_by(id: user_id)
    { id: user&.id, name: user&.firstname }
  end

  def role_detail
    { id: self.role_id, name: Role.find_by(id: self.role_id)&.name }
  end

  def validate_role_member
    errors.add :role_id, :invalid unless role&.member?
  end

  def inherited?
    !inherited_from.nil?
  end

  # Returns the MemberRole from which self was inherited, or nil
  def inherited_from_member_role
    MemberRole.find_by_id(inherited_from) if inherited_from
  end

  # Destroys the MemberRole without destroying its Member if it doesn't have
  # any other roles
  def destroy_without_member_removal
    @member_removal = false
    destroy
  end

  private

  def remove_member_if_empty
    if @member_removal != false && member.roles.reload.empty?
      member.destroy
    end
  end

  def add_role_to_group_users
    return if inherited? || !member.principal.is_a?(Group)

    member.principal.users.ids.each do |user_id|
      user_member = Member.find_or_initialize_by(:project_id => member.project_id, :user_id => user_id)
      user_member.member_roles << MemberRole.new(:role_id => role_id, :inherited_from => id)
      user_member.save!
    end
  end

  def add_role_to_subprojects
    return if member.project.leaf?

    member.project.children.where(:inherit_members => true).ids.each do |subproject_id|
      child_member = Member.find_or_initialize_by(:project_id => subproject_id, :user_id => member.user_id)
      child_member.member_roles << MemberRole.new(:role => role, :inherited_from => id)
      child_member.save!
    end
  end

  def remove_inherited_roles
    MemberRole.where(:inherited_from => id).destroy_all
  end
end
