class ActivityLogsController < ApplicationController
  def index
    @entity_types = ActivityLog.distinct.pluck(:entity_type)
    @field_names = ActivityLog.distinct.pluck(:field_name)
    @authors = User.where(id: ActivityLog.distinct.pluck(:author_id)).map { |u| ["#{u.firstname} #{u.lastname}", u.id] }
    @activity_logs = ActivityLog.order(created_at: :desc).where("created_at >= ?", 1.month.ago).all

    if params[:entity_type].present?
      @activity_logs = @activity_logs.where(entity_type: params[:entity_type]).where.not(entity_type: "UserPreference")
    end

    if params[:field_name].present?
      @activity_logs = @activity_logs.where(field_name: params[:field_name])
    end

    if params[:author].present?
      @activity_logs = @activity_logs.where(author_id: params[:author])
    end
    if params[:start_date].present? && params[:end_date].present?
      @activity_logs = @activity_logs.where(created_at: params[:start_date]..params[:end_date])
    elsif params[:start_date].present?
      
      @activity_logs = @activity_logs.where('created_at >= ?', params[:start_date])
    elsif params[:end_date].present?
      @activity_logs = @activity_logs.where('created_at <= ?', params[:end_date])
    end
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @activity_logs = @activity_logs.where("old_value LIKE ? OR new_value LIKE ?", search_term, search_term)
    end
    
  
    @activity_logs = @activity_logs.paginate(page: params[:page], per_page: 10)
  end
end