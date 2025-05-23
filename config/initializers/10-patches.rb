# frozen_string_literal: true

module ActiveRecord
  class Base
    # Translate attribute names for validation errors display
    def self.human_attribute_name(attr, options = {})
      prepared_attr = attr.to_s.sub(/_id$/, '').sub(/^.+\./, '')
      class_prefix = name.underscore.tr('/', '_')

      redmine_default = [
        :"field_#{class_prefix}_#{prepared_attr}",
        :"field_#{prepared_attr}"
      ]

      options[:default] = redmine_default + Array(options[:default])

      super
    end
  end

  # Undefines private Kernel#open method to allow using `open` scopes in models.
  # See Defect #11545 (http://www.redmine.org/issues/11545) for details.
  class Base
    class << self
      undef open
    end
  end
  class Relation ; undef open ; end
end

module ActionView
  module Helpers
    module DateHelper
      # distance_of_time_in_words breaks when difference is greater than 30 years
      def distance_of_date_in_words(from_date, to_date = 0, options = {})
        from_date = from_date.to_date if from_date.respond_to?(:to_date)
        to_date = to_date.to_date if to_date.respond_to?(:to_date)
        distance_in_days = (to_date - from_date).abs

        I18n.with_options :locale => options[:locale], :scope => :'datetime.distance_in_words' do |locale|
          case distance_in_days
            when 0..60     then locale.t :x_days,             :count => distance_in_days.round
            when 61..720   then locale.t :about_x_months,     :count => (distance_in_days / 30).round
            else                locale.t :over_x_years,       :count => (distance_in_days / 365).floor
          end
        end
      end
    end
  end

  class Resolver
    def find_all(name, prefix=nil, partial=false, details={}, key=nil, locals=[])
      locals = locals.map(&:to_s).sort!.freeze

      cached(key, [name, prefix, partial], details, locals) do
        if (details[:formats] & [:xml, :json]).any?
          details = details.dup
          details[:formats] = details[:formats].dup + [:api]
        end
        _find_all(name, prefix, partial, details, key, locals)
      end
    end
  end
end

ActionView::Base.field_error_proc = Proc.new{ |html_tag, instance| html_tag || ''.html_safe }

# HTML5: <option value=""></option> is invalid, use <option value="">&nbsp;</option> instead
module ActionView
  module Helpers
    module Tags
      class Base
        private
        alias :add_options_without_non_empty_blank_option :add_options
        def add_options(option_tags, options, value = nil)
          if options[:include_blank] == true
            options = options.dup
            options[:include_blank] = '&nbsp;'.html_safe
          end
          add_options_without_non_empty_blank_option(option_tags, options, value)
        end
      end
    end

    module FormHelper
      alias :date_field_without_max :date_field
      def date_field(object_name, method, options = {})
        date_field_without_max(object_name, method, options.reverse_merge(max: '9999-12-31'))
      end
    end

    module FormTagHelper
      alias :select_tag_without_non_empty_blank_option :select_tag
      def select_tag(name, option_tags = nil, options = {})
        if options.delete(:include_blank)
          options[:prompt] = '&nbsp;'.html_safe
        end
        select_tag_without_non_empty_blank_option(name, option_tags, options)
      end

      alias :date_field_tag_without_max :date_field_tag
      def date_field_tag(name, value = nil, options = {})
        options[:max] = '9999-12-31'

        if action_name == "settings"
          target = name.match(/\[(\d+)\]/)&.captures&.first&.to_i
          custom_field = CustomField.find_by_id(target)

          if custom_field&.name&.in? ["Scheduled Start Date", "Scheduled End Date"]
            unless User.current.admin?
              @members = Member.where(project_id: @project.id)
              @role_present = @members.any? do |member|
                member.user_id == User.current.id && member.roles.pluck(:name).any? { |role| role.in?(["PMO", "Program Manager"]) }
              end
              options[:disabled] = true unless @role_present
            end
          end
        end
        date_field_tag_without_max(name, value, options)
      end
    end

    module FormOptionsHelper
      alias :options_for_select_without_non_empty_blank_option :options_for_select
      def options_for_select(container, selected = nil)
        if container.is_a?(Array)
          container = container.map {|element| element.presence || ["&nbsp;".html_safe, ""]}
        end
        options_for_select_without_non_empty_blank_option(container, selected)
      end
    end
  end
end

require 'mail'

module DeliveryMethods
  class TmpFile
    def initialize(*args); end

    def deliver!(mail)
      dest_dir = File.join(Rails.root, 'tmp', 'emails')
      Dir.mkdir(dest_dir) unless File.directory?(dest_dir)
      filename = "#{Time.now.to_i}_#{mail.message_id.gsub(/[<>]/, '')}.eml"
      File.binwrite(File.join(dest_dir, filename), mail.encoded)
    end
  end
end

ActionMailer::Base.add_delivery_method :tmp_file, DeliveryMethods::TmpFile

module ActionController
  module MimeResponds
    class Collector
      def api(&block)
        any(:xml, :json, &block)
      end
    end
  end
end

module ActionController
  class Base
    # Displays an explicit message instead of a NoMethodError exception
    # when trying to start Redmine with an old session_store.rb
    # TODO: remove it in a later version
    def self.session=(*args)
      $stderr.puts "Please remove config/initializers/session_store.rb and run `rake generate_secret_token`.\n" +
        "Setting the session secret with ActionController.session= is no longer supported."
      exit 1
    end
  end
end

# Adds asset_id parameters to assets like Rails 3 to invalidate caches in browser
module ActionView
  module Helpers
    module AssetUrlHelper
      @@cache_asset_timestamps = Rails.env.production?
      @@asset_timestamps_cache = {}
      @@asset_timestamps_cache_guard = Mutex.new

      def asset_path_with_asset_id(source, options = {})
        asset_id = rails_asset_id(source, options)
        unless asset_id.blank?
          source += "?#{asset_id}"
        end
        asset_path(source, options.merge(skip_pipeline: true))
      end
      alias :path_to_asset :asset_path_with_asset_id

      def rails_asset_id(source, options = {})
        if asset_id = ENV["RAILS_ASSET_ID"]
          asset_id
        else
          if @@cache_asset_timestamps && (asset_id = @@asset_timestamps_cache[source])
            asset_id
          else
            extname = compute_asset_extname(source, options)
            path = File.join(Rails.public_path, "#{source}#{extname}")
            exist = false
            if File.exist? path
              exist = true
            else
              path = File.join(Rails.public_path, public_compute_asset_path("#{source}#{extname}", options))
              if File.exist? path
                exist = true
              end
            end
            asset_id = exist ? File.mtime(path).to_i.to_s : ''

            if @@cache_asset_timestamps
              @@asset_timestamps_cache_guard.synchronize do
                @@asset_timestamps_cache[source] = asset_id
              end
            end

            asset_id
          end
        end
      end
    end
  end
end

# https://github.com/rack/rack/pull/1703
# TODO: remove this when Rack is updated to 3.0.0
require 'rack'
module Rack
  class RewindableInput
    unless method_defined?(:size)
      def size
        make_rewindable unless @rewindable_io
        @rewindable_io.size
      end
    end
  end
end
