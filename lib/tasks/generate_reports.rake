namespace :reports do
    desc 'Generate and send weekly status reports'
    task generate_reports: :environment do
      WeeklyStatusReport.generate_and_send_reports
    end
end
  