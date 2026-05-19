import { Comment, CreateCommentDTO, buildCommentTree } from '../models/comment'
import { db } from '../utils/database'
import { sendEmail } from '../utils/email'
import { PostService } from './post-service'
import { UserService } from './user-service'

const postService = new PostService()
const userService = new UserService()

export class CommentService {
  async create(authorId: number, dto: CreateCommentDTO): Promise<Comment> {
    const post = await postService.findById(dto.post_id)
    if (!post) throw new Error('Post not found')

    if (dto.parent_id) {
      const parent = await db.findOne('comments', { id: dto.parent_id })
      if (!parent || parent.post_id !== dto.post_id) {
        throw new Error('Invalid parent comment')
      }
    }

    const comment = await db.insert('comments', {
      post_id: dto.post_id,
      author_id: authorId,
      parent_id: dto.parent_id || null,
      content: dto.content,
      created_at: new Date(),
      updated_at: new Date(),
      is_deleted: false,
    })

    // Notify post author
    const postAuthor = await userService.findById(post.author_id)
    if (postAuthor && postAuthor.id !== authorId) {
      const commenter = await userService.findById(authorId)
      sendEmail(
        postAuthor.email,
        `New comment on "${post.title}"`,
        `${commenter?.username || 'Someone'} commented on your post.`
      )
    }

    return comment
  }

  async getByPost(postId: number): Promise<Comment[]> {
    const comments = await db.findMany('comments', {
      post_id: postId,
      is_deleted: false,
    }, { orderBy: 'created_at ASC' })

    return comments
  }

  async getTreeByPost(postId: number) {
    const comments = await this.getByPost(postId)
    return buildCommentTree(comments)
  }

  async update(id: number, authorId: number, content: string): Promise<Comment> {
    const comment = await db.findOne('comments', { id })
    if (!comment) throw new Error('Comment not found')
    if (comment.author_id !== authorId) throw new Error('Not authorized')

    return db.update('comments', { id }, {
      content,
      updated_at: new Date(),
    })
  }

  async softDelete(id: number, userId: number): Promise<void> {
    const comment = await db.findOne('comments', { id })
    if (!comment) throw new Error('Comment not found')

    const user = await userService.findById(userId)
    if (comment.author_id !== userId && user?.role !== 'admin') {
      throw new Error('Not authorized')
    }

    await db.update('comments', { id }, {
      is_deleted: true,
      content: '[deleted]',
      updated_at: new Date(),
    })
  }

  async countByPost(postId: number): Promise<number> {
    return db.count('comments', { post_id: postId, is_deleted: false })
  }
}
