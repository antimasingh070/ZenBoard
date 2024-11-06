# frozen_string_literal: true

module Redmine
  class Notifiable < Struct.new(:name, :parent)

    def to_s
      name
    end
 
    # TODO: Plugin API for adding a new notification?
    def self.all
      notifications = []
      notifications << Notifiable.new('project_created')
      notifications << Notifiable.new('project_updated')
      notifications << Notifiable.new('project_status')
      notifications << Notifiable.new('issue_added')
      notifications << Notifiable.new('issue_updated')
      notifications << Notifiable.new('issue_approved')
      notifications << Notifiable.new('issue_send_back')
      notifications << Notifiable.new('issue_declined')
      notifications << Notifiable.new('issue_pending_approval')
      notifications << Notifiable.new('issue_note_added', 'issue_updated')
      notifications << Notifiable.new('issue_status_updated', 'issue_updated')
      notifications << Notifiable.new('issue_assigned_to_updated', 'issue_updated')
      notifications << Notifiable.new('issue_priority_updated', 'issue_updated')
      notifications << Notifiable.new('issue_fixed_version_updated', 'issue_updated')
      notifications << Notifiable.new('news_added')
      notifications << Notifiable.new('news_comment_added')
      notifications << Notifiable.new('document_added')
      notifications << Notifiable.new('file_added')
      notifications << Notifiable.new('message_posted')
      notifications << Notifiable.new('wiki_content_added')
      notifications << Notifiable.new('wiki_content_updated')
      notifications << Notifiable.new('send_wsr_email')
      notifications << Notifiable.new('send_issue_list')
      notifications << Notifiable.new('membership_added_email')
      notifications << Notifiable.new('membership_deleted_email')
      notifications << Notifiable.new('send_dashboard_email')
      notifications << Notifiable.new('business_requirement_created')
      notifications << Notifiable.new('meeting_invitation')
      notifications
    end
  end
end
