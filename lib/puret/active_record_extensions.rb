module Puret
  module ActiveRecordExtensions
    module ClassMethods
      # Configure translation model dependency.
      # Eg:
      #   class PostTranslation < ActiveRecord::Base
      #     puret_for :post
      #   end
      def puret_for(model)
        belongs_to model
        validates_presence_of :locale
        validates_uniqueness_of :locale, :scope => "#{model}_id"
      end

      # Configure translated attributes.
      # Eg:
      #   class Post < ActiveRecord::Base
      #     puret :title, :description
      #   end
      def puret(*attributes)
        unique_locale = attributes.delete(:locale)
        make_it_puret(unique_locale) unless included_modules.include?(InstanceMethods)
        set_unique_locale(unique_locale)

        attributes.each do |attribute|
          # attribute setter
          define_method "#{attribute}=" do |value|
            current_locale = has_unique_locale? ? locale.to_sym : I18n.locale
            puret_attributes[current_locale][attribute] = value
          end

          # attribute getter
          define_method attribute do
            # return previously setted attributes if present
            current_locale = has_unique_locale? ? locale.to_sym : I18n.locale
            return puret_attributes[current_locale][attribute] if !puret_attributes[current_locale][attribute].nil?
            return if new_record?

            # Lookup chain:
            #   - if translation not present in current locale, use fallbacks if present,
            #   - else, use the default locale, if present
            #   - else, use a translation which provides the attribute,
            #   - otherwise use first translation.
            locales_priority = [I18n.locale]
            if I18n.respond_to?(:fallbacks) && fallbacks = I18n.fallbacks[I18n.locale]
              locales_priority += fallbacks
            end
            locales_priority << puret_default_locale

            found_locale = locales_priority.detect { |locale| translations.find { |t| t.locale.to_sym == locale && !t[attribute].nil? } }

            translation = ( found_locale && translations.find { |t| t.locale.to_sym == found_locale } ) ||
                          translations.detect { |t| !t[attribute].nil? } ||
                          translations.first

            translation ? translation[attribute] : nil
          end

          define_method "#{attribute}_before_type_cast" do
            self.send(attribute)
          end
        end
      end

      private

      def set_unique_locale(unique_locale)
        if unique_locale
          define_method "locale" do
            (translations.first ? translations.first.locale : I18n.locale.to_s)
          end
          define_method "locale=" do |value|
            puret_attributes[:unique_locale] = value
          end
          define_method "has_unique_locale?" do
            true
          end
        else
          define_method "has_unique_locale?" do
            false
          end
        end

      end

      # configure model
      def make_it_puret(unique = false)
        include InstanceMethods

        has_many :translations, -> { order('created_at DESC') }, :class_name => "#{self.to_s}Translation", :dependent => :destroy
        validates_associated :translations
        after_save (unique ? :update_unique_translation! : :update_translations!)
      end
    end

    module InstanceMethods
      def changed?
        super || puret_attributes != {}
      end

      def puret_default_locale
        return default_locale.to_sym if respond_to?(:default_locale)
        return self.class.default_locale.to_sym if self.class.respond_to?(:default_locale)
        I18n.default_locale
      end

      # attributes are stored in @puret_attributes instance variable via setter
      def puret_attributes
        @puret_attributes ||= Hash.new { |hash, key| hash[key] = {} }
      end

      def reload(options = nil)
        @puret_attributes = nil
        super
      end

      # called after save
      def update_translations!
        return if puret_attributes.blank?
        puret_attributes.each do |locale, attributes|
          translation = translations.where(locale: locale.to_s).first || translations.new(locale: locale.to_s)
          translation.attributes = translation.attributes.merge(attributes)
          translation.save!
        end
      end

      # called after save
      def update_unique_translation!
        return if puret_attributes.blank?
        locale_attribute =  puret_attributes.delete(:unique_locale)
        unique_locale = (locale_attribute if locale_attribute.present?) || locale
        puret_attributes.each do |locale, attributes|
          translation = reload.translations.first_or_initialize
          translation.attributes = translation.attributes.merge(attributes).merge(locale: unique_locale)
          translation.save!
        end
      end
    end
  end
end

ActiveRecord::Base.extend Puret::ActiveRecordExtensions::ClassMethods
