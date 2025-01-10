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

class WelcomeController < ApplicationController
  self.main_menu = false

  skip_before_action :check_if_login_required, only: [:robots]
  # STATUS_ACTIVE     = 1
  # STATUS_CLOSED     = 5
  # STATUS_ARCHIVED   = 9
  # STATUS_SCHEDULED_FOR_DELETION = 10
  # STATUS_HOLD = 11
  # STATUS_CANCELLED = 12

  def download_help_documents
    document = Document.find(params[:id]) # Fetch the document by ID
    # Check if the document has an associated attachment (or file)
    if document && document.attachments.any?
      # Send the file for download
      attachment = document.attachments.first
      
      send_file attachment.diskfile,
                filename: attachment.filename,
                type: attachment.content_type,
                disposition: 'attachment' # Forces download
    else
      # If the document or attachment doesn't exist, respond with a 404
      head :not_found
    end
  end
  
  def project_score_card
    # Determine the start of the current financial year (April to March)
    if Date.today.month >= 4
      financial_year_start = Date.new(Date.today.year, 4, 1)
    else
      financial_year_start = Date.new(Date.today.year - 1, 4, 1)
    end
      # Filter Roles by matching name starting with param
    if params[:role].present?
      @roles = Role.where("name LIKE ?", "#{params[:role]}%")
    end

    # Filter Users by matching firstname starting with param
    if params[:member_name].present?
      @users = User.where("firstname LIKE ?", "#{params[:member_name]}%")
    end
    role = Role.find_by(name: params[:role])
    firstname, lastname = params[:member_name].to_s.split(' ', 2)
    user = User.find_by(firstname: firstname, lastname: lastname)

    @projects = Project.where(status: 5)
    @projects = @projects.joins(members: :roles).where(roles: { id: role.id }) if role
    @projects = @projects.joins(:members).where(members: { user_id: user.id }) if user
    @projects = @projects.joins(members: :roles).where(roles: { id: role.id }, members: { user_id: user.id }) if role && user

    custom_field = CustomField.find_by(name: "Is IT Project?")
    customized_ids = CustomValue.where(custom_field_id: custom_field.id, value: "1").pluck(:customized_id)
    @projects = @projects.where(id: customized_ids)
    @average_delay = calculate_average_delay(@projects)
    @top_delayed_projects = get_top_delayed_projects(@projects)
    @total_last_year = calculate_delay_percentage(1.year.ago.change(month: 4, day: 1).to_date, Date.new(Date.today.year, 3, 1))

    @total_year_to_date = calculate_delay_percentage(financial_year_start, Date.today)
    @total_this_month = calculate_delay_percentage(Time.current.beginning_of_month.to_date, Date.today)
  end

  def projects_for_period
    period = params[:period] # Assuming 'last_year', 'year_to_date', or 'this_month' is passed
    if Date.today.month >= 4
      financial_year_start = Date.new(Date.today.year, 4, 1)
    else
      financial_year_start = Date.new(Date.today.year - 1, 4, 1)
    end

    beginning_of_year = financial_year_start.beginning_of_year
    case period
    when 'last_year'
      redirect_url = "http://localhost:3000/projects?utf8=%E2%9C%93&set_filter=1&sort=&f%5B%5D=cf_36&op%5Bcf_36%5D=%3E%3C&v%5Bcf_36%5D%5B%5D=#{1.year.ago.change(month: 4, day: 1).to_date}&v%5Bcf_36%5D%5B%5D=#{Date.new(Date.today.year, 3, 1).to_date}&f%5B%5D=&display_type=board&c%5B%5D=name&c%5B%5D=identifier&c%5B%5D=short_description&group_by="
      "http://localhost:3000/projects?utf8=%E2%9C%93&set_filter=1&sort=&f%5B%5D=cf_36&op%5Bcf_36%5D=%3E%3C&v%5Bcf_36%5D%5B%5D=2023-04-01&v%5Bcf_36%5D%5B%5D=2024-03-01&f%5B%5D=status&op%5Bstatus%5D=%3D&v%5Bstatus%5D%5B%5D=5&f%5B%5D=&display_type=board&c%5B%5D=name&c%5B%5D=identifier&c%5B%5D=short_description&group_by="
    when 'year_to_date'
      redirect_url = "http://localhost:3000/projects?utf8=%E2%9C%93&set_filter=1&sort=&f%5B%5D=cf_36&op%5Bcf_36%5D=%3E%3C&v%5Bcf_36%5D%5B%5D=#{financial_year_start}&v%5Bcf_36%5D%5B%5D=#{Date.today}&f%5B%5D=&display_type=board&c%5B%5D=name&c%5B%5D=identifier&c%5B%5D=short_description&group_by="
    when 'this_month'
      redirect_url = "http://localhost:3000/projects?utf8=%E2%9C%93&set_filter=1&sort=&f%5B%5D=cf_36&op%5Bcf_36%5D=%3E%3C&v%5Bcf_36%5D%5B%5D=#{Date.today.beginning_of_month.to_date}&v%5Bcf_36%5D%5B%5D=#{Date.today}&f%5B%5D=&display_type=board&c%5B%5D=name&c%5B%5D=identifier&c%5B%5D=short_description&group_by="
    else
      redirect_url = nil
    end

    if redirect_url
      render json: { redirect_url: redirect_url }
    else
      render json: { error: 'Invalid period specified' }, status: :unprocessable_entity
    end
  end

  def calculate_average_delay(projects)
    total_delay = 0
    valid_projects_count = 0
    
    projects.each do |project|
      planned_project_go_live_date = fetch_custom_field_date(project, 'Planned Project Go Live Date')

      cf = CustomField.find_by(name: "Actual End Date")
      cv = CustomValue.find_by(customized_type: "Project", customized_id: project.id, custom_field_id: cf.id)
      actual_end_date = cv&.value&.to_date
      
      next unless planned_project_go_live_date && actual_end_date
      
      delay = (actual_end_date - planned_project_go_live_date).to_i
      next if delay <= 0
      
      total_delay += delay
      valid_projects_count += 1
    end
    return 0 if valid_projects_count.zero?
    total_delay / projects.count
  end

  def fetch_custom_field_date(project, field_name)
    custom_field = CustomField.find_by(name: field_name)
    return unless custom_field
    
    custom_field_value = project.custom_field_values.find { |cfv| cfv.custom_field_id == custom_field.id }
    custom_field_value&.value&.to_date
  end

  def get_top_delayed_projects(projects)
    holidays = [
      Date.new(Date.today.year, 1, 26),
      Date.new(Date.today.year, 8, 15),
      Date.new(Date.today.year, 10, 2),
      Date.new(Date.today.year, 12, 25),
      Date.new(Date.today.year, 5, 1)
    ]
    delayed_projects = projects.map do |project|
      planned_project_go_live_date = fetch_custom_field_date(project, 'Planned Project Go Live Date')

      cf = CustomField.find_by(name: "Actual End Date")
      cv = CustomValue.find_by(customized_type: "Project", customized_id: project.id, custom_field_id: cf.id)
      actual_end_date = cv&.value&.to_date
      
      next unless planned_project_go_live_date && actual_end_date
      # delay = (actual_end_date - scheduled_end_date).to_i

      working_days = 0
      current_date = planned_project_go_live_date

      while current_date <= actual_end_date

        unless current_date.sunday? || holidays.include?(current_date)
          working_days += 1
        end
        current_date = current_date.next_day
      end
      next unless working_days > 0
      { project: project, delay: working_days,  actual_end_date: actual_end_date}
    end.compact
    delayed_projects.sort_by { |data| -data[:actual_end_date].to_time.to_i }.take(3)
  end

  def calculate_delay_percentage(start_date, end_date)
    holidays = [
      Date.new(Date.today.year, 1, 26),
      Date.new(Date.today.year, 8, 15),
      Date.new(Date.today.year, 10, 2),
      Date.new(Date.today.year, 12, 25),
      Date.new(Date.today.year, 5, 1)
    ]
    
    @total_projects = 0.0
    projects_in_date_range = []
    
    @projects.each do |project|
      planned_project_go_live_date = fetch_custom_field_date(project, 'Planned Project Go Live Date')
      next unless planned_project_go_live_date
      next unless planned_project_go_live_date >= start_date && planned_project_go_live_date <= end_date
      
      projects_in_date_range << project
      @total_projects += 1
    end
  
    @delayed_projects = 0
    delayed_projects = []
    projects_in_date_range.each do |project|
      planned_project_go_live_date = fetch_custom_field_date(project, 'Planned Project Go Live Date')
      
      cf = CustomField.find_by(name: "Actual End Date")
      cv = CustomValue.find_by(customized_type: "Project", customized_id: project.id, custom_field_id: cf.id)
      actual_end_date = cv&.value&.to_date
      
      next unless planned_project_go_live_date && actual_end_date
      next unless planned_project_go_live_date >= start_date && planned_project_go_live_date <= end_date
      
      working_days = 0
      current_date = planned_project_go_live_date
      while current_date < actual_end_date
        unless current_date.sunday? || holidays.include?(current_date)
          working_days += 1
        end
        current_date = current_date.next_day
      end
      next unless working_days > 0
      delayed_projects << project
      @delayed_projects += 1
    end
    return { percentage: 100 - ((@delayed_projects / @total_projects * 100).round(2)), delayed_projects: delayed_projects }
  end
  

  def date_value(project, field_name)
    custom_field = CustomField.find_by(name: field_name)
    custom_value = CustomValue.find_by(customized_type: "Project", customized_id: project&.id, custom_field_id: custom_field&.id)
    date_string = custom_value&.value
  end

  def it_project_dashboard 
    cache_key = cache_key_for_dashboard
    cached_data = REDIS.get(cache_key)
    # if cached_data
    #   @projects, @categories, @functions, @statuses, @managers, @names, @subprojects, @next_week_go_live_projects = Marshal.load(cached_data)
    # else
      @project_status_text = {
        Project::STATUS_ACTIVE => 'Active',
        Project::STATUS_CLOSED => 'Closed',
        Project::STATUS_ARCHIVED => 'Archived',
        Project::STATUS_SCHEDULED_FOR_DELETION => 'Scheduled for Deletion',
        Project::STATUS_HOLD => "Hold",
        Project::STATUS_CANCELLED => "Cancelled"
      }
    
      # Optimize the subproject filter

      current_user_id = User.current.id
      name_filter = Array(params[:name_filter]).reject(&:blank?)
      if name_filter.any? && !name_filter.include?('all')
        @projects = Project.where(name: name_filter)
      else
        @projects = Project.where(parent_id: nil)
      end

      if params[:show_subprojects] == 'true'
        selected_project_ids = @projects.pluck(:id)
        subprojects = Project.where(parent_id: selected_project_ids)
        @projects = @projects.or(subprojects)
      else
        @projects = @projects.where(parent_id: nil)
      end

      @projects = @projects.joins("LEFT JOIN custom_values ON custom_values.customized_id = projects.id AND custom_values.customized_type = 'Project'")
      .joins("LEFT JOIN custom_fields ON custom_fields.id = custom_values.custom_field_id")
      .where("custom_fields.name = ?", 'Planned Project Go Live Date')
      .order("custom_values.value DESC")
      custom_field = CustomField.find_by(name: "Is It Project?")
      customized_ids = CustomValue.where(custom_field_id: custom_field.id, value: "1").pluck(:customized_id)
      @projects = @projects.where.not(name: "Master Project").where(id: customized_ids)

      @projects = @projects.where(status: params[:status_filter].to_i) if params[:status_filter].present?

      @projects = @projects.select { |project| member_names(project, 'Project Manager').include?(params[:manager_filter]) } if params[:manager_filter].present?
      @projects = @projects.select { |project| member_names(project, 'Program Manager').include?(params[:manager_filter]) } if params[:manager_filter].present?
      @projects = @projects.select{|project| custom_field_value(project, 'Project Category')&.include?(params[:category_filter])} if params[:category_filter].present?

      @projects = @projects.select do |project|
        function_values = custom_field_value(project, 'Function')
        if function_values.is_a?(Array)
          function_values.any? { |value| value.casecmp?(params[:function_filter]) }
        else
          function_values&.casecmp?(params[:function_filter])
        end
      end if params[:function_filter].present?
      if params[:start_date_from].present? && params[:start_date_to].present?
        start_date_range = Date.parse(params[:start_date_from])..Date.parse(params[:start_date_to])
        
        @projects = @projects.select do |project|
          start_date_str = date_value(project, 'Scheduled Start Date')
          next false unless start_date_str.present?
          
          start_date = Date.parse(start_date_str) 
          start_date_range.cover?(start_date) 
        end
      end

      if params[:end_date_from].present? && params[:end_date_to].present?
        end_date_range = Date.parse(params[:end_date_from])..Date.parse(params[:end_date_to])
        
        @projects = @projects.select do |project|
          end_date_str = date_value(project, 'Scheduled End Date') 
          next false unless end_date_str.present? 
          
          end_date = Date.parse(end_date_str) 
          end_date_range.cover?(end_date) 
        end
      end
      
      if User.current.admin?
        @projects# Show all projects if the user is an admin
      else
        @projects = @projects.select { |project| project.members.exists?(user_id: current_user_id) }  # Show only projects the user is a member of
      end
      @categories =@projects.map { |project| custom_field_value(project, 'Portfolio Category') }.compact.flatten.uniq
      @functions = @projects.flat_map { |project| custom_field_value(project, 'Function') }.compact.uniq
      @statuses = @projects.map { |project| @project_status_text[project.status] }.compact.uniq.sort
      @managers = @projects.flat_map { |project| member_names(project, 'Project Manager') }.compact.uniq.sort
      @names = @projects.select { |project| project.parent_id.nil? }.map(&:name).uniq.sort
      @subprojects = @projects.select { |project| !project.parent_id.nil? }.map(&:name).uniq.sort


      # Projects going live next week
      start_date_next_week = Date.today.next_week.beginning_of_week
      end_date_next_week = Date.today.next_week.end_of_week
      @next_week_go_live_projects = @projects.select { |project| 
        begin
          # Fetch the 'Revised End Date' value
          revised_end_date_str = date_value(project, 'Revised End Date')
          
          if revised_end_date_str.present?
            revised_end_date = Date.parse(revised_end_date_str)
            revised_end_date >= start_date_next_week && revised_end_date <= end_date_next_week
          else
            # If 'Revised End Date' is not present, check 'Planned Project Go Live Date'
            go_live_date_str = date_value(project, 'Planned Project Go Live Date')
            
            if go_live_date_str.present?
              go_live_date = Date.parse(go_live_date_str)
              go_live_date >= start_date_next_week && go_live_date <= end_date_next_week
            else
              false
            end
          end
        rescue ArgumentError, TypeError
          # Return false if parsing fails due to invalid date format or nil
          false
        end
      }
    
     # without pagination
      @total_project = @projects
      # Paginate through the existing projects
      @projects = @projects.paginate(page: params[:page], per_page: 5)
      REDIS.set(cache_key, Marshal.dump([@projects, @categories, @functions, @statuses, @managers, @names, @subprojects, @next_week_go_live_projects]), ex: 5.minutes.to_i)
    # end
  end

  def non_it_project_dashboard
    begin
    @project_status_text = {
      Project::STATUS_ACTIVE => 'Active',
      Project::STATUS_CLOSED => 'Closed',
      Project::STATUS_ARCHIVED => 'Archived',
      Project::STATUS_SCHEDULED_FOR_DELETION => 'Scheduled for Deletion',
      Project::STATUS_HOLD => "Hold",
      Project::STATUS_CANCELLED => "Cancelled"
    }

    current_user_id = User.current.id
    # Go Live date
    # @projects = Project.where(parent_id: nil)
    @projects = Project.where(parent_id: nil)
    .joins("LEFT JOIN custom_values ON custom_values.customized_id = projects.id AND custom_values.customized_type = 'Project'")
    .joins("LEFT JOIN custom_fields ON custom_fields.id = custom_values.custom_field_id")
    .where("custom_fields.name = ?", 'Planned Project Go Live Date')
    .order("custom_values.value DESC")
    custom_field = CustomField.find_by(name: "Is IT Project?")
    customized_ids = CustomValue.where(custom_field_id: custom_field.id, value: "0").pluck(:customized_id)
    @projects = @projects.where(id: customized_ids)
    @projects = @projects.where("custom_field_value(project, 'Project Category') = ?", params[:category_filter]) if params[:category_filter].present?

    @projects = @projects.where("custom_field_value(project, 'Function') = ?", params[:function_filter]) if params[:function_filter].present?
    @projects = @projects.where("custom_field_value(project, 'Template') = ?", params[:template_filter]) if params[:template_filter].present?
    @projects = @projects.where(status: params[:status_filter].to_i) if params[:status_filter].present?
    @projects = @projects.where("project.name = ?", params[:name_filter]) if params[:name_filter].present?
    @projects = @projects.select { |project| member_names(project, 'Project Manager').include?(params[:manager_filter]) } if params[:manager_filter].present?

    if params[:start_date_from].present? && params[:start_date_to].present?
      start_date_range = Date.parse(params[:start_date_from])..Date.parse(params[:start_date_to])
      @projects = @projects.select { |project| start_date_range.cover?(Date.parse(date_value(project, 'Scheduled Start Date'))) }
    end

    if params[:end_date_from].present? && params[:end_date_to].present?
      end_date_range = Date.parse(params[:end_date_from])..Date.parse(params[:end_date_to])
      @projects = @projects.select { |project| end_date_range.cover?(Date.parse(date_value(project, 'Scheduled End Date'))) }
    end

    @projects = @projects.select { |project| project.members.exists?(user_id: current_user_id) }
    @categories = @projects.map { |project| custom_field_value(project, 'Portfolio Category') }.compact.uniq
 
    @functions = @projects.map { |project| custom_field_value(project, 'Function') }.compact.uniq
    @templates = @projects.map { |project| custom_field_value(project, 'Template') }.compact.uniq
    @statuses = @projects.map { |project| @project_status_text[project.status] }.compact.uniq
    @managers = @projects.flat_map { |project| member_names(project, 'Project Manager') }.compact.uniq
    @top_delayed_projects = get_top_delayed_projects(@projects)
    @average_delay = calculate_average_delay(@projects)
    @names = @projects.map(&:name).compact.uniq
    # Projects going live next week
    start_date_next_week = Date.today.next_week.beginning_of_week
    end_date_next_week = Date.today.next_week.end_of_week
    @next_week_go_live_projects = @projects.select { |project| 
      go_live_date = Date.parse(date_value(project, 'Planned Project Go Live Date'))
      go_live_date >= start_date_next_week && go_live_date <= end_date_next_week
    }

    # Remove this line if you don't want to limit to the first 3 projects
    @next_week_go_live_projects = @next_week_go_live_projects[0..2]
    rescue => e
    end
  end
  
  def export_all_it
  end
  
  def member_names(project, field_name)
    project_lead_role = Role.find_by(name: field_name)
  
    member_ids_with_lead_role = MemberRole.where(role_id: project_lead_role.id).pluck(:member_id)
    project_lead_user_ids = Member.where(project_id: project.id, id: member_ids_with_lead_role).pluck(:user_id)
  
    if project_lead_user_ids.present?
      project_lead_users = User.where(id: project_lead_user_ids)
      project_lead_names = project_lead_users.pluck(:firstname, :lastname)
      return project_lead_names.map { |firstname, lastname| "#{firstname} #{lastname}" }
    else
      return []
    end
  end  

  def custom_field_value(project, field_name)
    if field_name = "Function"
    custom_field = CustomField.find_by(name: field_name)
    custom_values = CustomValue.where(customized_type: "Project", customized_id: project&.id, custom_field_id: custom_field&.id)
    custom_field_enumerations = custom_values.map do |cv|
      CustomFieldEnumeration.find_by(id: cv.value.to_i)
    end.compact
    custom_field_enumerations.map(&:name) # Or handle the names as needed
  end

  end

  def index
    @news = News.latest User.current
  end

  def robots
    @projects = Project.visible(User.anonymous) unless Setting.login_required?
    render :layout => false, :content_type => 'text/plain'
  end

  def send_weekly_status_report(format)
    # Generate the weekly status report based on the specified format (csv or pdf)
    report_data = generate_report_data

    case format
    when 'csv'
      generate_csv_report(report_data)
    when 'pdf'
      generate_pdf_report(report_data)
    else
      raise ArgumentError, "Invalid report format: #{format}. Supported formats are 'csv' and 'pdf'."
    end

    # Print a message indicating the report was generated
    puts "Weekly status report generated in #{format} format."
  end

  private

  def cache_key_for_dashboard
    "dashboard/#{params[:name_filter].to_s}/#{params[:show_subprojects]}/#{params[:category_filter]}/#{params[:function_filter]}/#{params[:status_filter]}/#{params[:manager_filter]}/#{params[:start_date_from]}/#{params[:start_date_to]}/#{params[:end_date_from]}/#{params[:end_date_to]}/#{Date.today.to_s}"
  end
  
  def generate_report_data
    # Logic to fetch data for the weekly status report
    # This could involve querying the database or any other data source
    # For demonstration purposes, let's return dummy data
    Issue.where(status_id: [1, 2, 3])  # Example: Fetch issues with open, in progress, or re-opened statuses
  end

  def generate_csv_report(report_data)
    # Logic to generate the CSV report
    # For simplicity, let's print the report data
    puts "CSV Report:"
    report_data.each do |issue|
      puts "#{issue.id}, #{issue.subject}, #{issue.status.name}, #{issue.assigned_to&.name}"
    end
  end

  def generate_pdf_report(report_data)
    # Logic to generate the PDF report
    # For simplicity, let's print the report data
    puts "PDF Report:"
    report_data.each do |issue|
      puts "#{issue.id} | #{issue.subject} | #{issue.status.name} | #{issue.assigned_to&.name}"
    end
  end

end

