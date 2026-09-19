# frozen_string_literal: true

require_relative '../test_helper'
require 'comfy_middle_seat'

class VersionTest < ActiveSupport::TestCase
  def test_version
    assert_equal 'constant', defined?(ComfyMiddleSeat::VERSION)
    refute_empty ComfyMiddleSeat::VERSION
    refute defined?(ComfortableMediaSurfer)
  end

  def test_eager_loading_with_renamed_gem
    assert_nothing_raised { Rails.application.eager_load! }
    assert_equal 'constant', defined?(ComfyMiddleSeat::VERSION)
  end
end
