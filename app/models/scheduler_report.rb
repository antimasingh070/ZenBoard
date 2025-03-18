class SchedulerReport < ActiveRecord::Base

    after_create :log_create_activity
    after_update :log_update_activity
    after_destroy :log_destroy_activity


    def log_create_activity
      activity_log = ActivityLog.create(
        entity_type: 'SchedulerReport',
        entity_id: self.id,
        field_name: 'Create',
        old_value: nil,
        new_value: self.attributes.to_json,
        author_id: User.current.id
      )
    end
    # changes_hash
    def log_update_activity
      saved_changes.each do |field_name, values|
        ActivityLog.create(
          entity_type: 'SchedulerReport',
          entity_id: self.id,
          field_name: field_name,
          old_value: values[0].to_s,
          new_value: values[1].to_s,
          author_id: User.current.id
        )
      end
    end

    def log_destroy_activity
      activity_log = ActivityLog.create(
        entity_type: 'SchedulerReport',
        entity_id: self.id,
        field_name: 'Delete',
        old_value: self.attributes.to_json,
        new_value: nil,
        author_id: User.current.id
      )
    end

    def self.pmo_alert_for_overdue_closed_project
       puts "PMO alert for overdue closed project"
      projects = Project.where(status: 5, parent_id: nil).where.not(name: "Master Project")
      user = User.first
  
      Mailer.deliver_pmo_alert_for_overdue_closed_project(user, projects.pluck(:id))
    end

    def self.send_issue_lists
      projects = Project.where(status: 1, parent_id: nil)
      user  = User.first
      projects.each do |project|
      if project.issues.where(status_id: 1).present?
        @overdue_issues = project.issues.where(status_id: 1).select do |issue|
          # Check for the presence of a revised planned due date
          revised_due_date = custom_field_value_date(user, issue, "Revised planned due date")
          
          if revised_due_date.present?
            # If revised planned due date is present, check if it has passed
            revised_due_date.to_date < Date.today
          else
            # If no revised planned due date, check the original due date
            issue.due_date.present? && issue.due_date < Date.today
          end
        end
        if @overdue_issues.any?
          Mailer.deliver_send_issue_list(user, project, @overdue_issues)
          puts "Mail sent for project #{project.name}" 
        end
      end
      end
    end

    def self.generate_and_send_reports
        projects = Project.all
        projects.each do  |project|
            user  = User.first
            send_report(user, project)
        end
      end
    
    
      def self.send_report(user, project)
        if Setting.notified_events.include?('send_wsr_email')
          Mailer.deliver_send_wsr_email(user, project)
          report = generate_report
          puts "WSR mail sent for project #{project.name}"
        end
      end    

      def self.generate_report
        report = self.new(
          report_date: Date.today
        )
        report.save
        report
      end

      def self.generate_and_send_risk_report
        projects = Project.where.not(name: "Master Project")
        tracker = Tracker.find_by(name: "Risk Register")
        return unless tracker
      
        risks = project.issues.where(status_id: 5, tracker_id: tracker.id)
        return if risks.blank?
        if Setting.notified_events.include?('send_risk')
          Mailer.deliver_send_risk(user, projects)
          generate_report # Ensure this method generates the desired report properly
          puts "Risk or challenges mail sent for project #{projects.pluck(:name)}"
        end
      end      

      def self.custom_field_value_date(user,issue, field_name) 
        custom_field = CustomField.find_by(name: field_name) 
        custom_value = CustomValue.find_by(customized_type: "Issue", customized_id: issue&.id, custom_field_id: custom_field&.id)
        custom_field_enumeration = custom_value&.value
        custom_field_enumeration
      end

      def self.custom_field_value(project, field_name)
        if field_name == "Project Activity"
          custom_field = CustomField.find_by(name: field_name)
          return "" unless custom_field
      
          # Fetch issues with the specific status and tracker ID
          issues = project.issues.where(status: 5, tracker_id: 2).includes(:custom_values)
          custom_field_id = CustomField.find_by(name: "Actual End Date")&.id
    
          if custom_field_id
            sorted_issues = issues.sort_by do |issue|
              end_date_value = issue.custom_values.find { |cv| cv.custom_field_id == custom_field_id }&.value
              begin
                end_date_value ? Date.parse(end_date_value) : nil
              rescue ArgumentError
                # Handle parsing errors by returning nil
                nil
              end
            end
            last_issue_id = sorted_issues.last&.id
          end
          custom_value = CustomValue.find_by(customized_type: "Issue", customized_id: last_issue_id, custom_field_id: custom_field&.id)
          return "" unless custom_value
          custom_field_enumeration = CustomFieldEnumeration.find_by(id: custom_value&.value&.to_i)
          completed_date = ""
          last_issue = sorted_issues.last
        end
      end

      def self.date_value(project, field_name)
        custom_field = CustomField.find_by(name: field_name)
        custom_value = CustomValue.find_by(customized_type: "Project", customized_id: project&.id, custom_field_id: custom_field&.id)
        date_string = custom_value&.value
      end
end
