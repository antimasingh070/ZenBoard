# lib/mailer_script.rb

class MailerScript
    def self.send_issue_email
      # user= User.first
      users.each do |user|
        Mailer.deliver_send_issue_pdf(user, '/Users/user/ZenBoard/app/issues.pdf')
      end
    end

    def self.send_dashboard_email
      # user= User.first
      users.each do |user|
        Mailer.deliver_send_dashboard_email(user, '/Users/user/ZenBoard/project_dashboard.csv','/Users/user/ZenBoard/project_dashboard_pdf_generated.pdf')
      end
    end

    def self.send_wsr_emails
      User.all.each do |user|
        projects = user.projects.where(status: 1)
        projects.each do  |project|
          Mailer.deliver_send_wsr_email(user, project)
          puts "Mail sent for project #{project.name}"
        end
      end
    end
  end
  