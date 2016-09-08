require "active_support/core_ext/class/attribute"

module PgSearch
  module Multisearchable
    def self.included mod
      mod.class_eval do
        has_one :pg_search_document,
          :as => :searchable,
          :class_name => "PgSearch::Document",
          :dependent => :delete

        if PgSearch.async_worker
          after_commit :async_update_pg_search_document,
            :if => lambda { PgSearch.multisearch_enabled? }
        else
          after_save :update_pg_search_document,
            :if => lambda { PgSearch.multisearch_enabled? }
        end

      end
    end

    def async_update_pg_search_document
      PgSearch.async_worker.perform_async self.class.name, self.id, :update_pg_search_document
    end

    def update_pg_search_document
      if_conditions = Array(pg_search_multisearchable_options[:if])
      unless_conditions = Array(pg_search_multisearchable_options[:unless])

      should_have_document =
        if_conditions.all? { |condition| condition.to_proc.call(self) } &&
        unless_conditions.all? { |condition| !condition.to_proc.call(self) }

      if should_have_document
        unless pg_search_document.present?
          build_pg_search_document.searchable_type = self.class.name
        end
        pg_search_document.save
      else
        pg_search_document.destroy if pg_search_document
      end
    end
  end
end
