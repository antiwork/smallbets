require "test_helper"

class LibrarySessionTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "after_commit enqueues thumbnail warm on create/update" do
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    begin
      assert_enqueued_with(job: Vimeo::FetchThumbnailJob, args: ["555666777"]) do
        @session = LibrarySession.create!(library_class: library_classes(:design_systems), vimeo_id: "555666777", padding: 56.25, position: 9, description: "d")
      end

      assert_enqueued_with(job: Vimeo::FetchThumbnailJob, args: ["555666778"]) do
        @session.update!(vimeo_id: "555666778")
      end
    ensure
      ActiveJob::Base.queue_adapter = previous_adapter
      LibrarySession.where(vimeo_id: ["555666777", "555666778"]).delete_all
    end
  end
end


