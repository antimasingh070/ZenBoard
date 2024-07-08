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

class Comment < ActiveRecord::Base
  include Redmine::SafeAttributes
  belongs_to :commented, :polymorphic => true, :counter_cache => true
  belongs_to :author, :class_name => 'User'

  validates_presence_of :commented, :author, :content

  after_create_commit :send_notification

  safe_attributes 'comments'

  after_create :log_create_activity
  after_update :log_update_activity
  after_destroy :log_destroy_activity

  def log_create_activity
    ActivityLog.create(
      entity_type: 'Comment',
      entity_id: self.id,
      field_name: 'Create',
      old_value: nil,
      new_value: comment_details.to_json,
      author_id: User.current.id
    )
  end

  def log_update_activity
    saved_changes.except('updated_at').each do |field_name, values|
      old_value = values[0].to_s
      new_value = values[1].to_s

      case field_name
      when 'user_id'
        old_value = User.find_by(id: values[0])&.firstname if values[0].present?
        new_value = User.find_by(id: values[1])&.firstname if values[1].present?
      when 'commentable_id'
        old_value = commentable_detail_name(values[0]) if values[0].present?
        new_value = commentable_detail_name(values[1]) if values[1].present?
      end

      ActivityLog.create(
        entity_type: 'Comment',
        entity_id: self.id,
        field_name: field_name,
        old_value: old_value,
        new_value: new_value,
        author_id: User.current.id
      )
    end
  end

  def log_destroy_activity
    ActivityLog.create(
      entity_type: 'Comment',
      entity_id: self.id,
      field_name: 'Delete',
      old_value: comment_details.to_json,
      new_value: nil,
      author_id: User.current.id
    )
  end

  def comment_details
    {
      id: self.id,
      content: self.content,
      author: user_detail(self.user_id),
      commented_on: self.created_at,
      updated_on: self.updated_at,
      commentable: commentable_detail
    }
  end

  def user_detail(user_id)
    user = User.find_by(id: user_id)
    { id: user&.id, name: user&.firstname }
  end

  def commentable_detail
    case self.commentable_type
    when 'Issue'
      issue = Issue.find_by(id: self.commentable_id)
      { id: issue&.id, subject: issue&.subject }
    when 'Project'
      project = Project.find_by(id: self.commentable_id)
      { id: project&.id, name: project&.name }
    when 'News'
      news = News.find_by(id: self.commentable_id)
      { id: news&.id, title: news&.title }
    when 'Document'
      document = Document.find_by(id: self.commentable_id)
      { id: document&.id, title: document&.title }
    when 'WikiPage'
      wiki_page = WikiPage.find_by(id: self.commentable_id)
      { id: wiki_page&.id, title: wiki_page&.title }
    else
      { id: self.commentable_id, type: self.commentable_type }
    end
  end

  def commentable_detail_name(id)
    case self.commentable_type
    when 'Issue'
      issue = Issue.find_by(id: id)
      issue&.subject
    when 'Project'
      project = Project.find_by(id: id)
      project&.name
    when 'News'
      news = News.find_by(id: id)
      news&.title
    when 'Document'
      document = Document.find_by(id: id)
      document&.title
    when 'WikiPage'
      wiki_page = WikiPage.find_by(id: id)
      wiki_page&.title
    else
      nil
    end
  end

  def comments=(arg)
    self.content = arg
  end

  def comments
    content
  end

  private

  def send_notification
    event = "#{commented.class.name.underscore}_comment_added"
    if Setting.notified_events.include?(event)
      Mailer.public_send("deliver_#{event}", self)
    end
  end
end
