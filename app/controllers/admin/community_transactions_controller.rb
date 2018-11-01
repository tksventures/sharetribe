require 'csv'

class Admin::CommunityTransactionsController < Admin::AdminBaseController

  def index
    @selected_left_navi_link = "transactions"
    pagination_opts = PaginationViewUtils.parse_pagination_opts(params)

    transactions = if params[:sort].nil? || params[:sort] == "last_activity"
      transactions_search_scope.for_community_sorted_by_activity(
        @current_community.id,
        sort_direction,
        pagination_opts[:limit],
        pagination_opts[:offset],
        request.format == :csv)
    else
      transactions_search_scope.for_community_sorted_by_column(
        @current_community.id,
        simple_sort_column(params[:sort]),
        sort_direction,
        pagination_opts[:limit],
        pagination_opts[:offset])
    end

    count = transactions_search_scope.exist.by_community(@current_community.id).with_payment_conversation.count
    transactions = WillPaginate::Collection.create(pagination_opts[:page], pagination_opts[:per_page], count) do |pager|
      pager.replace(transactions)
    end

    respond_to do |format|
      format.html do
        render("index", {
          locals: {
            community: @current_community,
            transactions: transactions,
          }
        })
      end
      format.csv do
        marketplace_name = if @current_community.use_domain
          @current_community.domain
        else
          @current_community.ident
        end

        self.response.headers["Content-Type"] ||= 'text/csv'
        self.response.headers["Content-Disposition"] = "attachment; filename=#{marketplace_name}-transactions-#{Date.today}.csv"
        self.response.headers["Content-Transfer-Encoding"] = "binary"
        self.response.headers["Last-Modified"] = Time.now.ctime.to_s

        self.response_body = Enumerator.new do |yielder|
          ExportTransactionsJob.generate_csv_for(yielder, transactions)
        end
      end
    end
  end

  def export
    @export_result = ExportTaskResult.create
    Delayed::Job.enqueue(ExportTransactionsJob.new(@current_user.id, @current_community.id, @export_result.id))
    respond_to do |format|
      format.js { render layout: false }
    end
  end

  def export_status
    export_result = ExportTaskResult.where(:token => params[:token]).first
    if export_result
      file_url = export_result.file.present? ? export_result.file.expiring_url(ExportTaskResult::AWS_S3_URL_EXPIRES_SECONDS) : nil
      render json: {token: export_result.token, status: export_result.status, url: file_url}
    else
      render json: {status: 'error'}
    end
  end

  private

  def simple_sort_column(sort_column)
    case sort_column
    when "listing"
      "listings.title"
    when "started"
      "created_at"
    end
  end

  def sort_direction
    if params[:direction] == "asc"
      "asc"
    else
      "desc" #default
    end
  end

  helper_method :transaction_search_status_titles

  def transaction_search_status_titles
    if params[:status].present?
      t("admin.communities.transactions.status_filter.selected", count: params[:status].size)
    else
      t("admin.communities.transactions.status_filter.all")
    end
  end

  def transactions_search_scope
    scope = Transaction
    if params[:q].present?
      pattern = "%#{params[:q]}%"
      scope = scope
        .joins(:starter, :listing_author)
        .where("listing_title like :pattern
        OR (people.given_name like :pattern OR people.family_name like :pattern OR people.display_name like :pattern)
        OR (listing_authors_transactions.given_name like :pattern
            OR listing_authors_transactions.family_name like :pattern
            OR listing_authors_transactions.display_name like :pattern)", pattern: pattern)
    end
    if params[:status].present?
      scope = scope.where(current_state: params[:status])
    end
    scope
  end
end
