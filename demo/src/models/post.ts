export interface Post {
  id: number
  title: string
  slug: string
  content: string
  author_id: number
  status: 'draft' | 'published' | 'archived'
  tags: string[]
  created_at: Date
  updated_at: Date
  published_at: Date | null
  view_count: number
  metadata: PostMetadata
}

export interface PostMetadata {
  seo_title: string
  seo_description: string
  og_image: string
  reading_time_minutes: number
}

export interface CreatePostDTO {
  title: string
  content: string
  tags?: string[]
  status?: 'draft' | 'published'
}

export interface UpdatePostDTO {
  title?: string
  content?: string
  tags?: string[]
  status?: 'draft' | 'published' | 'archived'
  metadata?: Partial<PostMetadata>
}

export function generateSlug(title: string): string {
  return title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')
}

export function estimateReadingTime(content: string): number {
  const words = content.split(/\s+/).length
  return Math.ceil(words / 200)
}
