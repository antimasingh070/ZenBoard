class BusinessRequirementsController < ApplicationController
    before_action :set_business_requirement, only: %i[show edit update destroy accept decline send_email meeting]
    helper :attachments
    # before_action :authorize, :only => [:index, :show, :edit, :update, :destroy, :accept, :decline, :send_email, :meeting]
    # accept_api_auth :index, :show, :edit, :update, :destroy, :accept, :decline, :send_email, :meeting
    def send_email
    
      @business_requirement = BusinessRequirement.find(params[:id])
    
      if @business_requirement.has_stakeholders?
        # Send email to all stakeholders in a single email
        program_manager_role = Role.find_by(name: "Program Manager")
        business_spoc_role = Role.find_by(name: "Business Spoc")
        # Fetch stakeholders with the "Program Manager" role
        program_manager_stakeholders = @business_requirement.br_stakeholders.where(role_id: [program_manager_role.id + business_spoc_role.id])
        Mailer.deliver_business_requirement_created(User.current, program_manager_stakeholders.pluck(:user_id), @business_requirement)
        redirect_to edit_business_requirement_path(@business_requirement), notice: 'Email sent successfully to all stakeholders.'
      else
        redirect_to @business_requirement, alert: 'Cannot send email: No stakeholders are associated with this business requirement.'
      end
    end

    def index
      begin
        # Start with the base query
        @business_requirements = if User.current.admin?
                                   BusinessRequirement.all
                                 else
                                   BusinessRequirement.joins(:br_stakeholders)
                                                      .where(br_stakeholders: { user_id: User.current.id })
                                                      .uniq
                                 end

       # Define and apply filters dynamically
        filters = {
          requirement_case: params[:requirement_case],
          requirement_received_from: params[:requirement_received_from],
          status: params[:statuses],
          priority_level: params[:priority_level],
          project_enhancement: params[:project_enhancement],
          identifier: params[:identifier]
        }
        filters.each do |key, value|
          next if value.blank? || value == ["all"] # Skip if the filter value is empty or nil
          status_keys = value.map { |v| BusinessRequirement::STATUS_MAP.key(v) }.compact
          if  key == :status
            @business_requirements = @business_requirements.where(key => status_keys) if status_keys.present?
          elsif key == :requirement_received_from
            @business_requirements = @business_requirements.select do |br|
              value.any? { |v| br.send(key)&.include?(v) }
            end
          elsif value.is_a?(Array) # Check if multiple values are selected
            @business_requirements = @business_requirements.where(key => value.reject(&:blank?)) # Remove empty values
          else
            @business_requirements = @business_requirements.where(key => value)
          end
          # if key == :requirement_received_from
          #   @business_requirements = @business_requirements.select { |br| br.send(key)&.include?(value) }
          # elsif key == :status
          #   @business_requirements = @business_requirements.where(key => status_key)
          # else
          #   @business_requirements = @business_requirements.where(key => value) if value.present?
          # end
        end
        if params[:project_manager_usernames].present?

          project_manager_role = Role.find_by(name: "Project Manager")
          
          if project_manager_role.present?
            project_manager_names = params[:project_manager_usernames].map { |name| name.split.map(&:capitalize).join(' ') }
            
            user_ids = User.where("CONCAT(firstname, ' ', lastname) IN (?)", project_manager_names).pluck(:id)
            
            @business_requirements = @business_requirements.joins(:br_stakeholders)
                                                          .where(br_stakeholders: { user_id: user_ids, role_id: project_manager_role.id })
          end
        end
  
        # Filter by Project Manager if selected
     

    
        # Fetch filtered unique values
        @requirement_case = @business_requirements.map(&:requirement_case).uniq.sort
        @requirement_received_from = @business_requirements.map(&:requirement_received_from).uniq.sort
        @identifier = @business_requirements.map(&:identifier).uniq.sort
        @statuses = @business_requirements.map { |br| BusinessRequirement::STATUS_MAP[br.status] }.compact.uniq.sort
        @project_manager_usernames = BrStakeholder.includes(:user).where(role_id: Role.find_by(name: "Project Manager")&.id).map { |stakeholder| "#{stakeholder.user.firstname} #{stakeholder.user.lastname}" }
        

        # Fetch custom field names
        @project_categories = fetch_custom_field_names('Project Category')
        @vendor_name = fetch_custom_field_names('Vendor Name')
        @portfolio_categories = fetch_custom_field_names('Portfolio Category')
        @priority_level = fetch_custom_field_names('Priority Level')
        @project_enhancement = fetch_custom_field_names('Project/Enhancement')
        @template = fetch_custom_field_names('Template')
        @requirement_received_from = fetch_custom_field_names('Function')
        @application_name = fetch_custom_field_names('Application Name')
        # Apply pagination
        @business_requirements = @business_requirements.paginate(page: params[:page], per_page: 5)
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.error "Error fetching records: #{e.message}"
         flash[:error] = ""
        @business_requirements = BusinessRequirement.none
      rescue StandardError => e
        Rails.logger.error "Unexpected error: #{e.message}"
        flash[:error] = ""
        @business_requirements = BusinessRequirement.none
      end
    end
    
    
    def export_all
      # Reuse the same logic used in the index action
      @business_requirements = if User.current.admin?
                                 BusinessRequirement.all
                               else
                                 BusinessRequirement.joins(:br_stakeholders)
                                                     .where(br_stakeholders: { user_id: User.current.id }).uniq
                               end
      # Apply any filters based on parameters, similar to the index method
      @business_requirements = @business_requirements.where(requirement_case: params[:requirement_case]) if params[:requirement_case].present?
      @business_requirements = @business_requirements.where("requirement_received_from LIKE ?", "%- #{params[:requirement_received_from]}\n%") if params[:requirement_received_from].present?
      if  params[:statuses].present?
        status_keys = params[:statuses].map { |v| BusinessRequirement::STATUS_MAP.key(v) }.compact
        @business_requirements = @business_requirements.where(status: status_keys) if status_keys.present?
      end
      @business_requirements = @business_requirements.where(priority_level: params[:priority_level]) if params[:priority_level].present?
      @business_requirements = @business_requirements.where(project_enhancement: params[:project_enhancement]) if params[:project_enhancement].present?
      @business_requirements = @business_requirements.where(portfolio_category: params[:portfolio_category]) if params[:portfolio_category].present?

      if params[:project_manager].present?
        # Get the role ID for 'Project Manager'
        project_manager_role = Role.find_by(name: "Project Manager")
      
        if project_manager_role.present?
          # Split and capitalize the project manager name
          project_manager_name = params[:project_manager].split.map(&:capitalize).join(' ')
      
          # Find the user ID(s) matching the name
          user_ids = User.where("CONCAT(firstname, ' ', lastname) = ?", project_manager_name).pluck(:id)
      
          # Filter business requirements where br_stakeholders match the role and user
          @business_requirements = @business_requirements.joins(:br_stakeholders)
                                                         .where(br_stakeholders: { user_id: user_ids, role_id: project_manager_role.id })
        end
      end   
      # Generate the CSV
      respond_to do |format|
        format.csv do
          send_data generate_csv(@business_requirements), filename: "business_requirements.csv"
        end
        format.json do
          render json: @business_requirements.as_json(include: { br_stakeholders: { include: :user } })
        end
      end
    end

    def show
      @project_categories = fetch_custom_field_names('Project Category')
      @vendor_name = fetch_custom_field_names('Vendor Name')
      @portfolio_categories = fetch_custom_field_names('Portfolio Category')
      @priority_level = fetch_custom_field_names('Priority Level')
      @project_enhancement = fetch_custom_field_names('Project/Enhancement')
      @template = fetch_custom_field_names('Template')
      @requirement_received_from = fetch_custom_field_names('Function')
      @application_name = fetch_custom_field_names('Application Name')
    end
  
    def edit
      @users = User.all
      @roles = Role.all

      if params[:stakeholder_search].present?
        # Search users and roles based on the search term
        @filtered_users = User.where('name ILIKE ?', "%#{params[:stakeholder_search]}%")
        @filtered_roles = Role.where('name ILIKE ?', "%#{params[:stakeholder_search]}%")
      else
        @filtered_users = User.all
        @filtered_roles = Role.all
      end
      @project_categories = fetch_custom_field_names('Project Category')
      @vendor_name = fetch_custom_field_names('Vendor Name')
      @portfolio_categories = fetch_custom_field_names('Portfolio Category')
      @priority_level = fetch_custom_field_names('Priority Level')
      @project_enhancement = fetch_custom_field_names('Project/Enhancement')
      @template = fetch_custom_field_names('Template')
      @requirement_received_from = fetch_custom_field_names('Function')
      @application_name = fetch_custom_field_names('Application Name')
    end
    
    def new
      @users = User.all
      @roles = Role.all

      if params[:stakeholder_search].present?
        # Search users and roles based on the search term
        @filtered_users = User.where('name ILIKE ?', "%#{params[:stakeholder_search]}%")
        @filtered_roles = Role.where('name ILIKE ?', "%#{params[:stakeholder_search]}%")
      else
        @filtered_users = User.all
        @filtered_roles = Role.all
      end
      @business_requirement =BusinessRequirement.new
      @project_categories = fetch_custom_field_names('Project Category')
      @vendor_name = fetch_custom_field_names('Vendor Name')
      @portfolio_categories = fetch_custom_field_names('Portfolio Category')
      @priority_level = fetch_custom_field_names('Priority Level')
      @project_enhancement = fetch_custom_field_names('Project/Enhancement')
      @template = fetch_custom_field_names('Template')
      @requirement_received_from = fetch_custom_field_names('Function')
      @application_name = fetch_custom_field_names('Application Name')
    end
    
    def accept
      @business_requirement = BusinessRequirement.find(params[:id])
      # Check if BusinessRequirement is found and update it
      if @business_requirement && @business_requirement.update(business_requirement_params)
        mandatory_fields = [:is_it_project, :business_need_as_per_business_case, :priority_level, :requirement_submitted_date, :requirement_received_from, :portfolio_category, :project_category]
    
        # Validate mandatory fields
        mandatory_fields.each do |field|
          value = @business_requirement.send(field)
          if field == :portfolio_category || field == :requirement_received_from
           
            value = value.reject(&:blank?) if value.is_a?(Array)
          end
          if value.blank?
            flash[:error] = "#{field.to_s.humanize} can't be blank"
            return redirect_to business_requirements_path
          end
        end
    
        # Update the status to closed
        @business_requirement.update(status: 7)
    
        # Project creation and updation logic
        @project = Project.find_or_initialize_by(name: @business_requirement.requirement_case, description: @business_requirement.description)
    
        @parent = Project.where(id: @project.parent_id).first
        if @project.id.nil? && !@project.parent_id.nil? && !@parent.nil?
          new_identifier = "#{Project.where(parent_id: @project.parent_id).count + 1}"
          @project.identifier = "#{@parent.identifier}_#{new_identifier}"
        elsif @project.id.nil? && !@project.parent_id.nil?
          new_identifier = "#{@project.parent_id}_#{Project.where(parent_id: @project.parent_id).count + 1}"
          @project.identifier = "neo_#{new_identifier}"
        else
          @project.identifier = "neo_#{Project.where(parent_id: @project.parent_id).last.id + 1
          }"
        end
        @project.save(validate: false) if @project.new_record?
    
        # Custom field handling with exception handling
        custom_fields = {
          'Project Category' => @business_requirement.project_category,
          'Portfolio Category' => @business_requirement.portfolio_category,
          'Priority Level' => @business_requirement.priority_level,
          'Function' => @business_requirement.requirement_received_from,
          'Application Name' => @business_requirement.application_name,
          'Vendor Name' => @business_requirement.vendor_name,
          'Business Need' => @business_requirement.business_need_as_per_business_case,
          'Project/Enhancement' => @business_requirement.project_enhancement,
          'Is IT Project?' => @business_requirement.is_it_project,
          'Planned Project Go Live Date' => @business_requirement.planned_project_go_live_date,
          'Scheduled Start Date' => @business_requirement.requirement_submitted_date,
          'Scheduled End Date' => @business_requirement.scheduled_end_date,
          'Actual Start Date' => @business_requirement.actual_start_date,
          'Actual End Date' => @business_requirement.actual_end_date,
          'Template' => @business_requirement.template
        }
    
        custom_fields.each do |field_name, value|
          begin
            custom_field = CustomField.find_by(type: "ProjectCustomField", name: field_name)
            next unless custom_field
            # Handle different field types with exception handling
            case field_name
            when "Portfolio Category", "Application Name", "Function"
              CustomValue.where(customized_id: @project.id, custom_field_id: custom_field.id).delete_all
              custom_values = value.reject(&:blank?).map do |enumeration_name|
                enumeration = CustomFieldEnumeration.find_by(custom_field_id: custom_field.id, name: enumeration_name)
                if enumeration
                  custom_value = CustomValue.find_or_create_by(
                    customized_type: "Project",
                    customized_id: @project.id,
                    custom_field_id: custom_field.id
                  )
                  custom_value.value = enumeration.id
                  custom_value.save
                  custom_value
                end
              end.compact
    
              @project.custom_field_values = { custom_field.id => custom_values.first&.id }
    
            when "Project Category", "Priority Level", "Vendor Name", "Project/Enhancement"
              CustomValue.where(customized_id: @project.id, custom_field_id: custom_field.id).delete_all
              enumeration = CustomFieldEnumeration.find_by(custom_field_id: custom_field.id, name: value)
              if enumeration
                custom_value = CustomValue.find_or_create_by(
                  customized_type: "Project",
                  customized_id: @project.id,
                  custom_field_id: custom_field.id,
                  value: enumeration.id
                )
                @project.custom_field_values = { custom_field.id => custom_value }
              end
    
            when "Is IT Project?"
              CustomValue.where(customized_id: @project.id, custom_field_id: custom_field.id).delete_all
              custom_value = CustomValue.find_or_create_by(
                customized_type: "Project",
                customized_id: @project.id,
                custom_field_id: custom_field.id,
                value: value ? "1" : "0"
              )
              @project.custom_field_values = { custom_field.id => custom_value }
    
            when "Template"
              auto_create_records(@project, @business_requirement, value) # Assuming auto_create_records is a defined method
              enumeration = CustomFieldEnumeration.find_by(custom_field_id: custom_field.id, name: value)
              if enumeration
                custom_value = CustomValue.find_or_create_by(
                  customized_type: "Project",
                  customized_id: @project.id,
                  custom_field_id: custom_field.id,
                  value: enumeration.id
                )
                @project.custom_field_values = { custom_field.id => custom_value }
              end
    
            else
              custom_value = CustomValue.find_or_initialize_by(customized_type: "Project", customized_id: @project.id, custom_field_id: custom_field.id)
              if custom_field.field_format == 'list' && custom_field.multiple
                custom_value.value = value.reject(&:blank?) # Remove any blank values
                custom_value.save
                @project.custom_field_values = { custom_field.id => custom_value }
              else
                custom_value.value = value
                custom_value.save
                @project.custom_field_values = { custom_field.id => custom_value }
              end
            end
    
          rescue => e
            # Handle the error and display the message
            flash[:error] = "Failed to create or update project. Error: #{field_name} #{value} #{e.message}"
            return redirect_to business_requirements_path
          end
        end
    
        @business_requirement.update(project_identifier: @project.identifier)
    
        # Add Business Requirement members to the project (Assuming add_members_to_project is a defined method)
        add_members_to_project(@business_requirement, @project)
    
        # Attach Business Requirement files to the project as documents (Assuming attach_files_to_project is a defined method)
        attach_files_to_project(@business_requirement, @project)

        if @project.save
          flash[:success] = 'Business Requirement successfully accepted, updated, and project created.'
          return redirect_to project_path(@project)
        elsif @project.id.present?
          flash[:success] = "Business Requirement successfully accepted, updated, and project created.."
          return redirect_to project_path(@project)
        else
          flash[:error] = " #{@project.errors.full_messages} Failed to create project."
          return redirect_to business_requirements_path
        end
      end
    end

    def create
        @business_requirement = BusinessRequirement.new(business_requirement_params)
        @business_requirement.is_it_project = true
        @project_categories = fetch_custom_field_names('Project Category')
        @vendor_name = fetch_custom_field_names('Vendor Name')
        @portfolio_categories = fetch_custom_field_names('Portfolio Category')
        @priority_level = fetch_custom_field_names('Priority Level')
        @project_enhancement = fetch_custom_field_names('Project/Enhancement')
        # @template = fetch_custom_field_names('Template')
        @requirement_received_from = fetch_custom_field_names('Function')
        @application_name = fetch_custom_field_names('Application Name')
        @business_requirement.is_it_project = true
        if @business_requirement.project_enhancement == "Project"
          @business_requirement.template = "IT"
        elsif @business_requirement.project_enhancement == "Enhancement"
          @business_requirement.template = "IT Enhancement"
        end
        if @business_requirement.save
          # Mailer.deliver_business_requirement_created(User.current, @business_requirement)
          attach_files(@business_requirement)
          redirect_to edit_business_requirement_path(@business_requirement), notice: 'Business Requirement was successfully created. Please add Stackholders'
        else
          # Collect all error messages and join them into a single string
          error_messages = @business_requirement.errors.full_messages.join(", ")
          # Render the form again, with the current form data
          render :new
        end
      rescue ActiveRecord::RecordInvalid => e
        flash.now[:alert] = "An error occurred: #{e.message}"
        render :new
    end
  
    def meeting
    end

    def update
      if @business_requirement.update(business_requirement_params)
        if @business_requirement.project_enhancement == "Project"
          @business_requirement.update(template: "IT")
        elsif @business_requirement.project_enhancement == "Enhancement"
          @business_requirement.update(template: "IT Enhancement")
        else
          @business_requirement.update(template: "")
        end
        attach_files(@business_requirement)
        redirect_to edit_business_requirement_path(@business_requirement), notice: 'Business Requirement was successfully updated.'
      end
    end

    def destroy
      @business_requirement.destroy
      redirect_to business_requirements_path(@business_requirement), notice: 'Business Requirement was successfully deleted.'
    end
  
    def hold
      @business_requirement = BusinessRequirement.find(params[:id])
      @business_requirement.update(status: 6)
      @business_requirement.status_logs.create(
        status: 6,
        updated_by: User.current.name,   # assuming you're using Devise and the current user is available
        reason: params[:remarks],         # assuming the reason is passed as a parameter
        updated_at: Time.current
      )
      redirect_to business_requirements_url, notice: 'Business Requirement on Hold.'
    end

    def decline
      @business_requirement = BusinessRequirement.find(params[:id])
      # Create a status log when the status is updated
      @business_requirement.update(status: 8)
      @business_requirement.status_logs.create(
        status: 8,
        updated_by: User.current.name,   # assuming you're using Devise and the current user is available
        reason: params[:remarks],         # assuming the reason is passed as a parameter
        updated_at: Time.current
      )
      redirect_to business_requirements_url, notice: 'Business Requirement was rejected.'
    end

    private

    def generate_csv(business_requirements)

      CSV.generate(headers: true) do |csv|
        # Adding headers
        csv << ['Identifier', 'Description', 'Requirement Case', 'Requirement Received From', 'Project Enhancement', 'Status', 'Priority Level', 'Stakeholders']
    
        # Adding rows
        business_requirements.each do |br|
          # Get project manager name using helper
          project_manager_name = get_project_manager_name(br)
    
          # Group stakeholders by role
          grouped_stakeholders = br.br_stakeholders.includes(:role, :user).group_by { |stakeholder| stakeholder.role.name }
          
          # Prepare stakeholder string (HTML-style list is not appropriate for CSV, instead we create a formatted string)
          stakeholder_info = grouped_stakeholders.map do |role_name, stakeholders|
            "#{role_name}: #{stakeholders.map { |stakeholder| stakeholder.user.name }.join(', ')}"
          end.join(" | ")
    
          # Add the row with necessary information
          csv << [
            br.identifier,
            br.description,
            br.requirement_case,
            br.requirement_received_from.reject(&:blank?).join(", "),
            br.project_enhancement,
            BusinessRequirement::STATUS_MAP[br.status],
            br.priority_level,
            stakeholder_info  # Formatted stakeholder info
          ].map { |value| "\"#{value}\"" }
        end
      end
    end    

    def get_project_manager_name(business_requirement)
      # Assuming the project manager has the role "Project Manager"
      project_manager_role = Role.find_by(name: "Project Manager")
      
      # Fetch the project manager's user name if the business requirement has this role
      project_manager = business_requirement.br_stakeholders
                                            .joins(:role)
                                            .where(role_id: project_manager_role.id)
                                            .first
      
      project_manager ? "#{project_manager.user.firstname} #{project_manager.user.lastname}" : "N/A"
    end

    def auto_create_records(project, business_requirement, template_value)
      template_field = CustomField.find_by(type: "ProjectCustomField", name: "Template")
      return unless template_field

      tracker = Tracker.find_by(name: template_value)
      return unless tracker
    
      master_project = Project.find_by(name: "Master Project")
      return unless master_project
    
      issues = Issue.where(tracker_id: tracker.id, project_id: master_project.id)
    
      plan_tracker = Tracker.find_by(name: "Project Plan- Activity List")
      return unless plan_tracker
    
      # Get all unique field names from CustomFields for Issues
      field_names = CustomField.where(type: "IssueCustomField").pluck(:name).uniq
      create_issues_for_field_names(project, business_requirement, field_names, issues, plan_tracker)
    end
  
    def create_issues_for_field_names(project, business_requirement, field_names, issues, plan_tracker)
      if  Issue.where(tracker_id: plan_tracker.id, project_id: project.id).count == 0
        project_manager_role_id = Role.find_by(name: "Project Manager")&.id
        return unless project_manager_role_id # Exit if the role does not exist

        # Fetch the first project manager's user ID for the current project
        first_project_manager  = BrStakeholder.where(business_requirement_id: business_requirement.id, role_id: project_manager_role_id).order(:created_at).first

        # Get the user_id if such a stakeholder exists
        project_manager_user_id = first_project_manager&.user_id
        issues.each do |issue|
          @new_issue = Issue.find_or_initialize_by(tracker_id: plan_tracker.id, project_id: project.id, subject: issue.subject)
          @new_issue.assigned_to_id = project_manager_user_id.present? ? project_manager_user_id : User.current.id
          @new_issue.author = User.current
          @new_issue.start_date = Date.today
          @new_issue.due_date = (Date.today + 10)
          field_names.each do |field_name|
            custom_field = CustomField.find_by(type: "IssueCustomField", name: field_name)
            next unless custom_field
            custom_value = CustomValue.find_or_create_by(customized_type: "Issue", customized_id: issue.id, custom_field_id: custom_field.id)
            custom_value.update(value: "") if custom_value.value.nil?
            next unless custom_value
            @new_issue.custom_field_values = { custom_field.id => custom_value }
          end
          approval_required_custom_field = CustomField.find_by(type: "IssueCustomField", name: "Approval Required")
          approval_required_custom_value = CustomValue.find_or_create_by(customized_type: "Issue", customized_id: issue.id, custom_field_id: approval_required_custom_field.id)
          approval_required_custom_value.update(value: "0")
          @new_issue.custom_field_values = { approval_required_custom_field.id => approval_required_custom_value }
          custom_field = CustomField.find_by(type: "IssueCustomField", name: "Project Activity")
          custom_field_enumeration = CustomFieldEnumeration.find_by(custom_field_id: custom_field.id, name: issue.subject)
          @new_issue.custom_field_values = { custom_field.id => custom_field_enumeration.id.to_s } unless custom_field_enumeration.nil?
          @new_issue.save
        end
      end
    end
      
    def add_members_to_project(business_requirement, project)
      business_requirement.br_stakeholders.each do |stackholder|
        begin
          # Begin a transaction to ensure atomic operation
          Member.transaction do
            # Find or create the member in the project
            member = Member.find_or_initialize_by(user_id: stackholder.user_id, project_id: project.id)
    
            if member.new_record?
              member.roles = [Role.find(stackholder.role_id)]
              member.save!
            end
    
            # Check if the member was successfully created or found
            if member.persisted?
              # Associate the member with the role
              MemberRole.find_or_create_by(member_id: member.id, role_id: stackholder.role_id, inherited_from: nil)
            else
              Rails.logger.error("Failed to create or find member with user_id: #{stackholder.user_id} for project: #{project.id}")
            end
          end
        rescue StandardError => e
          Rails.logger.error("Error while adding member to project: #{e.message}")
        end
      end
    end
    
    def attach_files(business_requirement)
      if params[:business_requirement][:attachments]
        params[:business_requirement][:attachments].each do |uploaded_file|
          business_requirement.attachments.create!(file: uploaded_file, author: User.current)
        end
      end
    end

    def attach_files_to_project(business_requirement, project)
      begin
        business_requirement.attachments.each do |attachment|
          document = Document.new(
            project: project,
            title: attachment.filename,
            description: 'Business Requirement Attachment',
            category: Enumeration.find_by(name: 'Uncategorized', type: 'DocumentCategory')
          )
          document.save!
          document.attachments.create!(container: document, filename: attachment.filename, disk_filename: attachment.disk_filename, filesize: attachment.filesize, content_type: attachment.content_type, digest: attachment.digest, downloads: 0, author_id: User.current.id, description: attachment.description, disk_directory: attachment.disk_directory)
        end
      rescue => e
      end
    end

    def fetch_custom_field_names(name)
      custom_field = CustomField.find_by(name: name)
      CustomFieldEnumeration.where(custom_field_id: custom_field.id).pluck(:name) if custom_field
    end

    def set_business_requirement
      @business_requirement = BusinessRequirement.find(params[:id])
    end
  
    def business_requirement_params
        params.require(:business_requirement).permit(:requirement_case, :identifier, :description, :cost_benefits, :status, :project_sponsor, :requirement_submitted_date, :scheduled_end_date, :actual_start_date, :actual_end_date, :revised_end_date, :business_need_as_per_business_case, :planned_project_go_live_date, :is_it_project, :project_category, :vendor_name, :priority_level, :project_enhancement, :template, portfolio_category: [], requirement_received_from: [], application_name: [], br_stakeholders_attributes: [:id, :user_id, :role_id, :_destroy])
    end
  end
  