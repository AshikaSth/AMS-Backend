module Paginatable
  extend ActiveSupport::Concern

  def paginate(scope)
    scope.page(params[:page]).per(params[:per_page] || 10)
  end

  def paginate_meta(scope)
    {
      current_page: scope.current_page,
      total_pages: scope.total_pages,
      total_entries: scope.total_count
    }
  end
end