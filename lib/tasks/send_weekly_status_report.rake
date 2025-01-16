namespace :send_weekly_status_report do
    desc "Send weekly status report"
    task send_report: :environment do
      WelcomeController.new.send_weekly_status_report('csv')
      WelcomeController.new.send_weekly_status_report('pdf')
    end
end
  