module SyncChecker
  module Formats
    class DetailedGuideCheck < EditionBase
      def root_path
        "/guidance/"
      end

      def checks_for_live(locale)
        super + [
          Checks::LinksCheck.new(
            "related_guides",
            edition_expected_in_live
              .published_related_detailed_guides
              .reject(&:unpublishing)
              .map(&:content_id)
              .uniq
          ),
          Checks::LinksCheck.new(
            "related_mainstream_content",
            related_mainstream_content_ids(edition_expected_in_live)
          )
        ]
      end

      def document_type
        "detailed_guide"
      end

      def expected_details_hash(edition)
        super.merge(
          related_mainstream_content: related_mainstream_content_ids(edition)
        )
      end

    private

      def related_mainstream_content_ids(edition)
        edition.related_mainstreams.pluck(:content_id)
      end
    end
  end
end
