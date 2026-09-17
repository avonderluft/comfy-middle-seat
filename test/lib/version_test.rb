# frozen_string_literal: true

require_relative '../test_helper'

class VersionTest < ActiveSupport::TestCase
  def test_version
    assert_equal 'constant', defined?(ComfortableMediaSurfer::VERSION)
    refute_empty ComfortableMediaSurfer::VERSION
  end

  def test_eager_loading_with_renamed_gem
    assert_nothing_raised { Rails.application.eager_load! }
    assert_equal 'constant', defined?(ComfortableMediaSurfer::VERSION)
  end
end
