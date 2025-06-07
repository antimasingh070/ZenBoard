# app/services/concerns/resource_utilities.rb
module ResourceUtilities
    def filter_projects_by_roles_and_members
    role = Role.where(name: @params[:roles])
    member = User.where(firstname: @params[:members].map { |name| name.split.first },
                        lastname: @params[:members].map { |name| name.split.last })

    return if role.blank? || member.blank?

    member_role_ids = MemberRole.where(role_id: role.pluck(:id)).pluck(:member_id)
    project_ids = Member.where(id: member_role_ids, user_id: member.pluck(:id)).pluck(:project_id)
    @projects = @projects.where(id: project_ids)
  end

  def load_roles
    @roles = Role.where.not(name: ["Anonymous", "Non member"]).pluck(:name)
  end

  def load_members
    @members = Member.includes(:user).where(project_id: @projects.ids).map { |m| full_name(m.user) }.uniq
  end

  def filter_member_names(names)
    @params[:members].present? ? names & @params[:members] : names
  end

  def full_name(user)
    "#{user.firstname} #{user.lastname}"
  end

  def fetch_user_from_name(full_name)
    firstname, lastname = full_name.split
    User.find_by(firstname: firstname, lastname: lastname)
  end

  def get_members_for_program_manager(projects, program_manager, role_name)
    filtered_projects = projects.select { |project| member_names(project, 'Program Manager').include?(program_manager) }
    members = filtered_projects.flat_map { |project| member_names(project, role_name) }.compact.uniq.sort
    { members: members, project_ids: filtered_projects.pluck(:id) }
  end

  def fetch_projects_with_member(project_ids, member_name, role)
    Project.where(id: project_ids).select { |project| member_names(project, role).include?(member_name) }
  end

  def format_project(project, member_name)
    {
      name: project.name,
      id: project.id,
      identifier: project.identifier,
      allocation: member_work_allocation(member_name, project.id)
    }
  end

  def member_work_allocation(member_name, project_id)
    user = fetch_user_from_name(member_name)
    Member.find_by(user_id: user&.id, project_id: project_id)&.work_allocation
  end

  def filtering_by_roles_and_members?
    @params[:roles].present? && @params[:members].present?
  end

  def filter_projects_by_role_and_member
    roles = Role.where(name: @params[:roles])
    names = @params[:members].map { |name| name.split }
    users = User.where(firstname: names.map(&:first), lastname: names.map(&:last))

    return [] if roles.blank? || users.blank?

    member_ids = MemberRole.where(role_id: roles.pluck(:id)).pluck(:member_id)
    project_ids = Member.where(id: member_ids, user_id: users.ids).pluck(:project_id)
    @projects = @projects.where(id: project_ids)

    @program_managers = if roles.one? && users.one? && roles.first.name == "Program Manager"
                          [full_name(users.first)]
                        else
                          load_program_managers
                        end
  end

  def load_program_managers
    @program_managers = @projects.includes(members: :user).flat_map do |project|
      fetch_member_names(project, "Program Manager")
    end.compact.uniq.sort
  end

  def fetch_member_names(project, role_name)
    role = Role.find_by(name: role_name)
    return [] unless role

    member_ids = MemberRole.where(role_id: role.id).pluck(:member_id)
    user_ids = Member.where(project_id: project.id, id: member_ids).pluck(:user_id)
    User.where(id: user_ids).pluck(:firstname, :lastname).map { |f, l| "#{f} #{l}" }
  end

  def member_names(project, field_name)
    role = Role.find_by(name: field_name)
    return [] unless role

    member_ids = MemberRole.where(role_id: role.id).pluck(:member_id)
    user_ids = Member.where(project_id: project.id, id: member_ids).pluck(:user_id)
    User.where(id: user_ids).pluck(:firstname, :lastname).map { |f, l| "#{f} #{l}" }
  end

  def working_day?(date)
    !(date.sunday? || (date.saturday? && date.day <= 14) || HOLIDAYS.include?(date))
  end

  def working_duration_across_projects(projects)
    start_dates = projects.filter_map { |p| parse_date(date_value(p, 'Scheduled Start Date')) }
    end_dates = projects.filter_map { |p| parse_date(date_value(p, 'Scheduled End Date')) }
    return "N/A" if start_dates.empty? || end_dates.empty?

    calculate_working_hours(start_dates.min, end_dates.max)
  end

  def working_duration_across_assigned_tasks(projects, manager)
    return "NA" if manager.blank?
    projects = projects.select { |p| member_names(p, "Project Manager").include?(manager) }
    return "" if projects.blank?

    user = fetch_user_from_name(manager)
    return "" unless user

    issues = Issue.where(project_id: projects.map(&:id), assigned_to_id: user.id).where.not(status: 5)
    return "" if issues.blank?

    start_date = issues.order(updated_on: :desc).last&.start_date
    end_date = issues.order(updated_on: :desc).first&.due_date

    return "N/A" unless start_date && end_date

    calculate_working_hours(start_date, end_date)
  end

  def calculate_working_hours(start_date, end_date)
    working_days = (start_date..end_date).select { |d| working_day?(d) }
    hours = working_days.size * 8
    hours.positive? ? "#{hours}h" : ""
  end

  def parse_date(date_string)
    Date.parse(date_string) rescue nil
  end

  def last_activity_from_all_assigned_task(manager, projects, field_name)
    return "" if projects.blank? || manager.blank? || field_name.blank?

    projects = projects.select { |p| member_names(p, "Project Manager").include?(manager) }
    return "" if projects.blank?

    custom_field = CustomField.find_by(name: field_name)
    return "" unless custom_field

    user = fetch_user_from_name(manager)
    return "" unless user

    issue = Issue.where(project_id: projects.map(&:id), assigned_to_id: user.id).where.not(status: 5).order(updated_on: :desc).first
    return "" unless issue

    custom_value = CustomValue.find_by(customized_type: "Issue", customized_id: issue.id, custom_field_id: custom_field.id)
    activity_name = CustomFieldEnumeration.find_by(id: custom_value&.value.to_i)&.name
    due_date = issue.due_date&.strftime("%d %b %y")

    activity_name.present? ? "#{activity_name} (#{due_date})" : ""
  end

  def last_activity_from_all_projects(role, member, projects, field_name)
    return "" if projects.blank? || member.blank? || field_name.blank?

    projects = projects.select { |p| member_names(p, role).include?(member) }
    return "" if projects.blank?

    custom_field = CustomField.find_by(name: field_name)
    return "" unless custom_field

    latest_project = projects.max_by do |p|
      parse_date(date_value(p, 'Scheduled End Date')) || Date.new(0)
    end
    return "" unless latest_project

    date_value = CustomValue.find_by(customized_type: "Project", customized_id: latest_project.id, custom_field_id: custom_field.id)&.value
    date_value.present? ? Date.parse(date_value).strftime('%d %b %y') : ""
  rescue
    ""
  end

  def total_work_allocation(role, member, projects, _field_name)
    return "" if projects.blank? || member.blank?

    projects = projects.select { |p| member_names(p, role).include?(member) }
    user = fetch_user_from_name(member)
    return "" unless user

    Member.where(user_id: user.id, project_id: projects.pluck(:id)).pluck(:work_allocation).compact.sum
  end

  def date_value(project, field_name)
    field = CustomField.find_by(name: field_name)
    CustomValue.find_by(customized_type: "Project", customized_id: project.id, custom_field_id: field&.id)&.value
  end
end
