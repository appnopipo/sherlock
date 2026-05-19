interface PaginationParams {
  page: number
  limit: number
  total: number
}

interface PaginationResult {
  currentPage: number
  totalPages: number
  hasNext: boolean
  hasPrev: boolean
  offset: number
  limit: number
}

export function usePagination({ page, limit, total }: PaginationParams): PaginationResult {
  const totalPages = Math.ceil(total / limit)

  return {
    currentPage: page,
    totalPages,
    hasNext: page < totalPages,
    hasPrev: page > 1,
    offset: (page - 1) * limit,
    limit,
  }
}

export function buildPaginationLinks(baseUrl: string, pagination: PaginationResult): Record<string, string> {
  const links: Record<string, string> = {}

  links.self = `${baseUrl}?page=${pagination.currentPage}&limit=${pagination.limit}`
  links.first = `${baseUrl}?page=1&limit=${pagination.limit}`
  links.last = `${baseUrl}?page=${pagination.totalPages}&limit=${pagination.limit}`

  if (pagination.hasNext) {
    links.next = `${baseUrl}?page=${pagination.currentPage + 1}&limit=${pagination.limit}`
  }
  if (pagination.hasPrev) {
    links.prev = `${baseUrl}?page=${pagination.currentPage - 1}&limit=${pagination.limit}`
  }

  return links
}
