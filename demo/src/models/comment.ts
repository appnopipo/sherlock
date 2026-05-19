export interface Comment {
  id: number
  post_id: number
  author_id: number
  parent_id: number | null
  content: string
  created_at: Date
  updated_at: Date
  is_deleted: boolean
}

export interface CreateCommentDTO {
  post_id: number
  content: string
  parent_id?: number
}

export function buildCommentTree(comments: Comment[]): CommentNode[] {
  const map = new Map<number, CommentNode>()
  const roots: CommentNode[] = []

  for (const comment of comments) {
    map.set(comment.id, { ...comment, replies: [] })
  }

  for (const comment of comments) {
    const node = map.get(comment.id)!
    if (comment.parent_id && map.has(comment.parent_id)) {
      map.get(comment.parent_id)!.replies.push(node)
    } else {
      roots.push(node)
    }
  }

  return roots
}

interface CommentNode extends Comment {
  replies: CommentNode[]
}
