# frozen_string_literal: true

module Decidim
  module Meetings
    module Admin
      # This class holds a Form to create/update translatable meetings from Decidim's admin panel.
      class MeetingForm < Decidim::Form
        include TranslatableAttributes

        attribute :address, String
        attribute :latitude, Float
        attribute :longitude, Float
        attribute :start_time, Decidim::Attributes::TimeWithZone
        attribute :end_time, Decidim::Attributes::TimeWithZone
        attribute :services, Array[MeetingServiceForm]
        attribute :decidim_scope_id, Integer
        attribute :decidim_category_id, Integer
        attribute :private_meeting, Boolean
        attribute :transparent, Boolean
        attribute :online_meeting_url, String
        attribute :type_of_meeting, String
        attribute :registration_type, String
        attribute :registration_url, String
        attribute :available_slots, Integer, default: 0
        attribute :customize_registration_email, Boolean

        translatable_attribute :title, String
        translatable_attribute :description, String
        translatable_attribute :location, String
        translatable_attribute :location_hints, String
        translatable_attribute :registration_email_custom_content, String

        validates :title, translatable_presence: true
        validates :description, translatable_presence: true
        validates :registration_type, presence: true
        validates :available_slots, numericality: { greater_than_or_equal_to: 0 }, presence: true, if: ->(form) { form.on_this_platform? }
        validates :registration_url, presence: true, url: true, if: ->(form) { form.on_different_platform? }
        validates :type_of_meeting, presence: true
        validates :location, translatable_presence: true, if: ->(form) { form.in_person_meeting? || form.hybrid_meeting? }

        validates :address, presence: true, if: ->(form) { form.needs_address? }
        validates :address, geocoding: true, if: ->(form) { form.has_address? && !form.geocoded? && form.needs_address? }
        validates :online_meeting_url, presence: true, url: true, if: ->(form) { form.online_meeting? || form.hybrid_meeting? }
        validates :start_time, presence: true, date: { before: :end_time }
        validates :end_time, presence: true, date: { after: :start_time }

        validates :current_component, presence: true
        validates :category, presence: true, if: ->(form) { form.decidim_category_id.present? }
        validates :scope, presence: true, if: ->(form) { form.decidim_scope_id.present? }
        validates :decidim_scope_id, scope_belongs_to_component: true, if: ->(form) { form.decidim_scope_id.present? }
        validates :clean_type_of_meeting, presence: true

        delegate :categories, to: :current_component

        def map_model(model)
          self.services = model.services.map do |service|
            MeetingServiceForm.from_model(service)
          end

          self.decidim_category_id = model.categorization.decidim_category_id if model.categorization
          presenter = MeetingPresenter.new(model)

          self.title = presenter.title(all_locales: title.is_a?(Hash))
          self.description = presenter.description(all_locales: description.is_a?(Hash))
          self.type_of_meeting = model.type_of_meeting
        end

        def services_to_persist
          services.reject(&:deleted)
        end

        def number_of_services
          services.size
        end

        alias component current_component

        # Finds the Scope from the given decidim_scope_id, uses component scope if missing.
        #
        # Returns a Decidim::Scope
        def scope
          @scope ||= @decidim_scope_id ? current_component.scopes.find_by(id: @decidim_scope_id) : current_component.scope
        end

        # Scope identifier
        #
        # Returns the scope identifier related to the meeting
        def decidim_scope_id
          @decidim_scope_id || scope&.id
        end

        def category
          return unless current_component

          @category ||= categories.find_by(id: decidim_category_id)
        end

        def geocoding_enabled?
          Decidim::Map.available?(:geocoding)
        end

        def has_address?
          geocoding_enabled? && address.present?
        end

        def needs_address?
          in_person_meeting? || hybrid_meeting?
        end

        def geocoded?
          latitude.present? && longitude.present?
        end

        def online_meeting?
          type_of_meeting == "online"
        end

        def in_person_meeting?
          type_of_meeting == "in_person"
        end

        def hybrid_meeting?
          type_of_meeting == "hybrid"
        end

        def clean_type_of_meeting
          type_of_meeting.presence
        end

        def type_of_meeting_select
          Decidim::Meetings::Meeting::TYPE_OF_MEETING.map do |type|
            [
              I18n.t("type_of_meeting.#{type}", scope: "decidim.meetings"),
              type
            ]
          end
        end

        def on_this_platform?
          registration_type == "on_this_platform"
        end

        def on_different_platform?
          registration_type == "on_different_platform"
        end

        def registration_type_select
          Decidim::Meetings::Meeting::REGISTRATION_TYPE.map do |type|
            [
              I18n.t("registration_type.#{type}", scope: "decidim.meetings"),
              type
            ]
          end
        end
      end
    end
  end
end
