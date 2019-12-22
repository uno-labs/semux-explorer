class ReversePaginator
  attr_reader :total, :limit, :total_pages, :page, :array

  def initialize(total:, limit:, page:)
    @total = total
    @limit = limit
    @page = page
    @total_pages = (total < limit) ? 1 : (total / limit)
    if @page > 0
      @array = yield(total - @page * limit, limit)
    else
      @page = @total_pages
      @array = yield(0, total % limit + limit)
    end
  end

  def each_on_page(&block)
    array.each(&block)    
  end

  def any_on_page?
    !array.empty?
  end

  def ai(*args)
    array.ai(*args)
  end

  def each_page
    total_pages.downto(1) { |page| yield page }
  end
end
