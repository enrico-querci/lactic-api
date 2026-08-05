# Emits pagination metadata as response headers.
#
# Deliberately headers rather than a wrapper object: the existing endpoints
# return a bare JSON array, and moving to `{ data: [...], meta: {...} }` would
# break the deployed web client the moment this ships. Headers add the
# information without changing the body's shape.
module Paginatable
  extend ActiveSupport::Concern

  def apply_pagination_headers(result)
    response.set_header("X-Total-Count", result.total_count.to_s)
    response.set_header("X-Page", result.page.to_s)
    response.set_header("X-Per-Page", result.per_page.to_s)
    response.set_header("X-Total-Pages", result.total_pages.to_s)
  end
end
