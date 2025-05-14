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

class WorkflowTransition < WorkflowRule
  validates_presence_of :new_status

  after_create :log_create_activity
  after_update :log_update_activity
  after_destroy :log_destroy_activity

  def workflow_transition_details
    {
      id: self.id,
      tracker: tracker_details,
      old_status_id: self.old_status_id,
      new_status_id: self.new_status_id,
      role: role_details,
      assignee: self.assignee,
      author: self.author
    }
  end

  def tracker_details
    { id: self.tracker_id, name: self.tracker.name }
  end

  def role_details
    { id: self.role_id, name: self.role.name }
  end

  # Logging methods
  def log_create_activity
    activity_log = ActivityLog.create(
      entity_type: 'WorkflowTransition',
      entity_id: self.id,
      field_name: 'Create',
      old_value: nil,
      new_value: workflow_transition_details.to_json,
      author_id: User.current.id
    )
  end

  def log_update_activity
    saved_changes.except('updated_on').each do |field_name, values|
      old_value = values[0].to_s
      new_value = values[1].to_s

      ActivityLog.create(
        entity_type: 'WorkflowTransition',
        entity_id: self.id,
        field_name: field_name,
        old_value: old_value,
        new_value: new_value,
        author_id: User.current.id
      )
    end
  end

  def log_destroy_activity
    activity_log = ActivityLog.create(
      entity_type: 'WorkflowTransition',
      entity_id: self.id,
      field_name: 'Delete',
      old_value: workflow_transition_details.to_json,
      new_value: nil,
      author_id: User.current.id
    )
  end

  def self.replace_transitions(trackers, roles, transitions)
    trackers = Array.wrap trackers
    roles = Array.wrap roles

    transaction do
      records = WorkflowTransition.where(:tracker_id => trackers.map(&:id), :role_id => roles.map(&:id)).to_a

      transitions.each do |old_status_id, transitions_by_new_status|
        transitions_by_new_status.each do |new_status_id, transition_by_rule|
          transition_by_rule.each do |rule, transition|
            trackers.each do |tracker|
              roles.each do |role|
                w = records.select do |r|
                  r.old_status_id == old_status_id.to_i &&
                  r.new_status_id == new_status_id.to_i &&
                  r.tracker_id == tracker.id &&
                  r.role_id == role.id &&
                  !r.destroyed?
                end
                if rule == 'always'
                  w = w.select {|r| !r.author && !r.assignee}
                else
                  w = w.select {|r| r.author || r.assignee}
                end
                if w.size > 1
                  w[1..-1].each(&:destroy)
                end
                w = w.first

                if ["1", true].include?(transition)
                  unless w
                    w = WorkflowTransition.
                          new(
                            :old_status_id => old_status_id,
                            :new_status_id => new_status_id,
                            :tracker_id => tracker.id,
                            :role_id => role.id
                          )
                    records << w
                  end
                  w.author = true if rule == "author"
                  w.assignee = true if rule == "assignee"
                  w.save if w.changed?
                elsif w
                  if rule == 'always'
                    w.destroy
                  elsif rule == 'author'
                    if w.assignee
                      w.author = false
                      w.save if w.changed?
                    else
                      w.destroy
                    end
                  elsif rule == 'assignee'
                    if w.author
                      w.assignee = false
                      w.save if w.changed?
                    else
                      w.destroy
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
