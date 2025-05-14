# frozen_string_literal: true

every :sunday, at: '12am' do
  rake 'send_weekly_status_report'
end

# every :sunday, at: '9am' do
#   rake 'wsr:send_weekly_status_emails'
# end

every :thursday, at: '12am' do
  runner "SchedulerReport.generate_and_send_reports"
end

every :monday, at: '9am' do
  runner "SchedulerReport.send_issue_lists"
end

every :monday, at: '9am' do
  runner "SchedulerReport.pmo_alert_for_overdue_closed_project"
end
# every :thursday, at: '12am' do
#   rake 'reports:generate_reports'
# end

# every 50.minute do
#   command "cd /Users/user/ZenBoard/app && curl -o issues.pdf 'http://localhost:3000/issues.pdf?api_key=c2abc90d5f095aeef1459ae4de37d50edd1b2ed8' && rails runner 'MailerScript.send_issue_email'"
# end

# every 50.minute, at: '7:00 am' do
#   command "cd /Users/user/ZenBoard && ruby download_csv.rb  && rails runner 'MailerScript.send_dashboard_email'"
# end

# # Run every day at 5:00 PM
# # every :day, at: '5:00 pm' do
# #   command "curl http://localhost:3000/issues.pdf"
# # end
