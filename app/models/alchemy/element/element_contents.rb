# Methods concerning contents for elements
#
module Alchemy
  module Element::ElementContents

    # Find first content from element by given name.
    def content_by_name(name)
      contents_by_name(name).first
    end

    # Find first content from element by given essence type.
    def content_by_type(essence_type)
      contents_by_type(essence_type).first
    end

    # All contents from element by given name.
    def contents_by_name(name)
      contents.where(name: name)
    end
    alias_method :all_contents_by_name, :contents_by_name

    # All contents from element by given essence type.
    def contents_by_type(essence_type)
      contents.where(essence_type: Content.normalize_essence_type(essence_type))
    end
    alias_method :all_contents_by_type, :contents_by_type

    # Updates all related contents by calling +update_essence+ on each of them.
    #
    # @param contents_attributes [Hash]
    #   Hash of contents attributes.
    #   The keys has to be the #id of the content to update.
    #   The values a Hash of attribute names and values
    #
    # @return [Boolean]
    #   True if +errors+ are blank or +contents_attributes+ hash is nil
    #
    # == Example
    #
    #   @element.update_contents(
    #     "1" => {ingredient: "Title"},
    #     "2" => {link: "https://google.com"}
    #   )
    #
    def update_contents(contents_attributes)
      return true if contents_attributes.nil?
      contents.each do |content|
        content_hash = contents_attributes["#{content.id}"] || next
        content.update_essence(content_hash) || errors.add(:base, :essence_validation_failed)
      end
      errors.blank?
    end

    # Copy current content's contents to given target element
    def copy_contents_to(element)
      contents.map do |content|
        Content.copy(content, element_id: element.id)
      end
    end

    # Returns the content that is marked as rss title.
    #
    # Mark a content as rss title in your +elements.yml+ file:
    #
    #   - name: news
    #     contents:
    #     - name: headline
    #       type: EssenceText
    #       rss_title: true
    #
    def content_for_rss_title
      content_for_rss_meta('title')
    end

    # Returns the content that is marked as rss description.
    #
    # Mark a content as rss description in your +elements.yml+ file:
    #
    #   - name: news
    #     contents:
    #     - name: body
    #       type: EssenceRichtext
    #       rss_description: true
    #
    def content_for_rss_description
      content_for_rss_meta('description')
    end

    # Returns the array with the hashes for all element contents in the elements.yml file
    def content_definitions
      return nil if definition.blank?
      definition['contents']
    end

    # Returns the definition for given content_name
    def content_definition_for(content_name)
      if content_definitions.blank?
        log_warning "Element #{name} is missing the content definition for #{content_name}"
        return nil
      else
        content_definitions.detect { |d| d['name'] == content_name }
      end
    end

    # Returns an array of all EssenceRichtext contents ids from elements
    #
    # This is used to initialize the TinyMCE editor in the element editor.
    #
    def richtext_contents_ids
      # This is not very efficient SQL wise I know, but we need to iterate
      # recursivly through all descendent elements and I don't know how to do this
      # in pure SQL. Anyone with a better idea is welcome to submit a patch.
      ids = contents.essence_richtexts.pluck("#{Content.table_name}.id")
      expanded_nested_elements = nested_elements.expanded
      if expanded_nested_elements.any?
        ids += expanded_nested_elements.collect(&:richtext_contents_ids)
      end
      ids.flatten
    end

    # True, if any of the element's contents has essence validations defined.
    def has_validations?
      !contents.detect(&:has_validations?).blank?
    end

    # All element contents where the essence validation has failed.
    def contents_with_errors
      contents.select(&:essence_validation_failed?)
    end

    private

    def content_for_rss_meta(type)
      definition = content_definitions.detect { |c| c["rss_#{type}"] }
      return if definition.blank?
      contents.find_by(name: definition['name'])
    end

    # creates the contents for this element as described in the elements.yml
    def create_contents
      contents = []
      if definition["contents"].blank?
        log_warning "Could not find any content definitions for element: #{name}"
      else
        definition["contents"].each do |content_hash|
          contents << Content.create_from_scratch(self, content_hash.symbolize_keys)
        end
      end
    end
  end
end
