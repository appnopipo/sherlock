import { Post, CreatePostDTO, UpdatePostDTO, generateSlug, estimateReadingTime } from '../models/post'
import { db } from '../utils/database'
import { cache } from '../utils/cache'

export class PostService {
  async findById(id: number): Promise<Post | null> {
    const cached = cache.get(`post:${id}`)
    if (cached) return cached as Post

    const post = await db.findOne('posts', { id })
    if (post) {
      cache.set(`post:${id}`, post, 600)
    }
    return post
  }

  async findBySlug(slug: string): Promise<Post | null> {
    return db.findOne('posts', { slug })
  }

  async create(authorId: number, dto: CreatePostDTO): Promise<Post> {
    const slug = generateSlug(dto.title)

    const existing = await this.findBySlug(slug)
    if (existing) {
      throw new Error('A post with a similar title already exists')
    }

    const readingTime = estimateReadingTime(dto.content)

    const post = await db.insert('posts', {
      title: dto.title,
      slug,
      content: dto.content,
      author_id: authorId,
      status: dto.status || 'draft',
      tags: dto.tags || [],
      created_at: new Date(),
      updated_at: new Date(),
      published_at: dto.status === 'published' ? new Date() : null,
      view_count: 0,
      metadata: {
        seo_title: dto.title,
        seo_description: dto.content.substring(0, 160),
        og_image: '',
        reading_time_minutes: readingTime,
      },
    })

    return post
  }

  async update(id: number, dto: UpdatePostDTO): Promise<Post> {
    const post = await this.findById(id)
    if (!post) throw new Error('Post not found')

    const updates: any = { ...dto, updated_at: new Date() }

    if (dto.title) {
      updates.slug = generateSlug(dto.title)
      updates.metadata = {
        ...post.metadata,
        seo_title: dto.title,
      }
    }

    if (dto.content) {
      updates.metadata = {
        ...(updates.metadata || post.metadata),
        reading_time_minutes: estimateReadingTime(dto.content),
        seo_description: dto.content.substring(0, 160),
      }
    }

    if (dto.status === 'published' && post.status !== 'published') {
      updates.published_at = new Date()
    }

    const updated = await db.update('posts', { id }, updates)
    cache.delete(`post:${id}`)

    return updated
  }

  async delete(id: number): Promise<void> {
    await db.update('posts', { id }, { status: 'archived', updated_at: new Date() })
    cache.delete(`post:${id}`)
  }

  async incrementViewCount(id: number): Promise<void> {
    const post = await this.findById(id)
    if (post) {
      await db.update('posts', { id }, { view_count: post.view_count + 1 })
      cache.delete(`post:${id}`)
    }
  }

  async listByAuthor(authorId: number, status?: string): Promise<Post[]> {
    const filter: any = { author_id: authorId }
    if (status) filter.status = status
    return db.findMany('posts', filter, { orderBy: 'created_at DESC' })
  }

  async listPublished(page: number, limit: number, tag?: string): Promise<{ posts: Post[]; total: number }> {
    const filter: any = { status: 'published' }
    if (tag) filter.tags = { contains: tag }

    const offset = (page - 1) * limit
    const [posts, total] = await Promise.all([
      db.findMany('posts', filter, { offset, limit, orderBy: 'published_at DESC' }),
      db.count('posts', filter),
    ])

    return { posts, total }
  }

  async searchPosts(query: string): Promise<Post[]> {
    return db.search('posts', ['title', 'content', 'tags'], query)
  }
}
