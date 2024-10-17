class BusinessRequirementsController < ApplicationController
    before_action :set_business_requirement, only: %i[show edit update destroy accept decline]
    helper :attachments
    def index
      @business_requirements = BusinessRequirement.all
      @project_categories = fetch_custom_field_names('Project Category')
      @vendor_name = fetch_custom_field_names('Vendor Name')
      @portfolio_categories = fetch_custom_field_names('Portfolio Category')
      @priority_level = fetch_custom_field_names('Priority Level')
      @project_enhancement = fetch_custom_field_names('Project/Enhancement')
      @template = fetch_custom_field_names('Template')
      @requirement_received_from = fetch_custom_field_names('Function')
      @application_name = fetch_custom_field_names('Application Name')
    end
  
    def show
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
        @business_requirement =BusinessRequirement.find(params[:id])
        if @business_requirement.update(business_requirement_params)
            mandatory_fields = [:is_it_project, :business_need_as_per_business_case, :priority_level, :requirement_submitted_date, :planned_project_go_live_date, :requirement_received_from, :portfolio_category, :project_category]
            mandatory_fields.each do |field|
              value = @business_requirement.send(field)
              if field == :portfolio_category || field == :requirement_received_from
                value = value.reject(&:blank?) if value.is_a?(Array)
              end
              if value.blank?
                flash[:success] = "#{field.to_s.humanize} can't be blank"
                return redirect_to business_requirements_path
              end
            end
             # Update the status to closed
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

            custom_fields.each do  |field_name, value|
              custom_field = CustomField.find_by(type: "ProjectCustomField", name: field_name)
              next unless custom_field
              if field_name == "Portfolio Category" || field_name == "Application Name" || field_name == "Function"
                # Delete existing custom values for this field
                CustomValue.where(customized_id: @project.id, custom_field_id: custom_field.id).delete_all

                # Initialize an empty array to store custom values
                custom_values = []
                value.each do |enumeration_name|
                  enumeration = CustomFieldEnumeration.find_by(custom_field_id: custom_field.id, name: enumeration_name)
                  if enumeration
                    custom_value = CustomValue.find_or_create_by(
                      customized_type: "Project",
                      customized_id: @project.id,
                      custom_field_id: custom_field.id,
                      value: enumeration.id
                    )

                    custom_values << custom_value
                    custom_value.update(value: "") if custom_value.value.nil?
                   
                    @project.custom_field_values = { custom_field.id => custom_values.map(&:value) }
                  end
                end

              elsif field_name == "Project Category" || field_name == "Priority Level" || field_name == "Vendor Name" || field_name == "Project/Enhancement" 
                # Delete existing custom values for this field
                CustomValue.where(customized_id: @project.id, custom_field_id: custom_field.id).delete_all
                enumeration = CustomFieldEnumeration.find_by(custom_field_id: custom_field.id, name: value)
                if enumeration
                  custom_value = CustomValue.find_or_create_by(customized_type: "Project", customized_id: @project.id, custom_field_id: custom_field.id, value: enumeration.id)
                  custom_value.update(value: "") if custom_value.value.nil?
                  @project.custom_field_values = { custom_field.id => custom_value }
                end
              elsif field_name == "Is IT Project?"
                CustomValue.where(customized_id: @project.id, custom_field_id: custom_field.id).delete_all
             
                if value == true
                  custom_value = CustomValue.find_or_create_by(customized_type: "Project", customized_id: @project.id, custom_field_id: custom_field.id, value: "1")
                  custom_value.update(value: "") if custom_value.value.nil?
                  @project.custom_field_values = { custom_field.id => custom_value }
                else
                  custom_value = CustomValue.find_or_create_by(customized_type: "Project", customized_id: @project.id, custom_field_id: custom_field.id, value: "0")
                  custom_value.update(value: "") if custom_value.value.nil?
                end
              elsif field_name == "Template"
                auto_create_records(@project, value)
                enumeration = CustomFieldEnumeration.find_by(custom_field_id: custom_field.id, name: value)
                custom_value = CustomValue.find_or_create_by(customized_type: "Project", customized_id: @project.id, custom_field_id: custom_field.id, value: enumeration.id)
                custom_value.update(value: "") if custom_value.value.nil?
                @project.custom_field_values = { custom_field.id => custom_value }
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
            end
            if @project.save
                @business_requirement.update(status: 7)
                @business_requirement.update(project_identifier: @project.identifier)
                # Add Business Requirement members to the project
                add_members_to_project(@business_requirement, @project)
                # Attach Business Requirement files to the project as documents
                attach_files_to_project(@business_requirement, @project)
          
                flash[:success] = 'Business Requirement successfully accepted, updated, and project created.'
                redirect_to project_path(@project)
            else
                flash[:error] = " #{@project.errors.full_messages} Failed to create project."
                redirect_to business_requirements_path
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
        else
          @business_requirement.template = "IT Enhancement"
        end
        if @business_requirement.save
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
  
    def update
      if @business_requirement.update(business_requirement_params)
        attach_files(@business_requirement)
        redirect_to @business_requirement, notice: 'Business Requirement was successfully updated.'
      end
    end

    def destroy
      @business_requirement.destroy
      redirect_to business_requirements_path(@business_requirement), notice: 'Business Requirement was successfully deleted.'
    end
  
    def decline
      @business_requirement = BusinessRequirement.find(params[:id])
      @business_requirement.update(status: 8)
      redirect_to business_requirements_url, notice: 'Business Requirement was rejected.'
    end
  
    private

    def auto_create_records(project, template_value)
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
      create_issues_for_field_names(project, field_names, issues, plan_tracker)
    end
  
    def create_issues_for_field_names(project, field_names, issues, plan_tracker)
      if  Issue.where(tracker_id: plan_tracker.id, project_id: project.id).count == 0
        issues.each do |issue|
          @new_issue = Issue.find_or_initialize_by(tracker_id: plan_tracker.id, project_id: project.id, subject: issue.subject)
          @new_issue.assigned_to_id = User.current.id
          @new_issue.author = User.current
          @new_issue.start_date = Date.today
          @new_issue.due_date = (Date.today +10)
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
  