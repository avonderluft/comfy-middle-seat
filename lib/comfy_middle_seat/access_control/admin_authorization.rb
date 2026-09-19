# frozen_string_literal: true

module ComfyMiddleSeat::AccessControl
  module AdminAuthorization
    # By default there's no authorization of any kind
    def authorize
      true
    end
  end
end
