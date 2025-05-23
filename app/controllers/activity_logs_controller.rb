# frozen_string_literal: true

class ActivityLogsController < ApplicationController
  def index
    @entity_types = ActivityLog.distinct.pluck(:entity_type)
    @field_names = ActivityLog.distinct.pluck(:field_name)
    @authors = User.where(id: ActivityLog.distinct.select(:author_id)).map { |u| ["#{u.firstname} #{u.lastname}", u.id] }
    daily_logins = ActivityLog.where(entity_type: "Token")
                          .group("DATE(created_at)")
                          .distinct
                          .count(:author_id)

    # Format the data for the chart
    @chart_data = daily_logins.map { |date, count| { date: date.strftime('%d %b %y'), count: count } }
    # Determine annotations (e.g., highest login day)
    highest_day = @chart_data.max_by { |data| data[:count] }
    @annotations = [
      {
        point: {
          x: @chart_data.index(highest_day),
          y: highest_day[:count]
        },
        text: "Highest Login Day: #{highest_day[:date]}"
      }
    ]
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
