import { Router, Request, Response } from 'express'
import { PostService } from '../../services/post-service'
import { CommentService } from '../../services/comment-service'
import { validateBody } from '../../validators/request'

const router = Router()
const postService = new PostService()
const commentService = new CommentService()

router.get('/', async (req: Request, res: Response) => {
  const page = parseInt(req.query.page as string) || 1
  const limit = parseInt(req.query.limit as string) || 10
  const tag = req.query.tag as string

  const result = await postService.listPublished(page, limit, tag)

  res.json({
    data: result.posts,
    pagination: {
      page,
      limit,
      total: result.total,
      pages: Math.ceil(result.total / limit),
    },
  })
})

router.get('/search', async (req: Request, res: Response) => {
  const query = req.query.q as string
  if (!query || query.length < 2) {
    return res.status(400).json({ error: 'Search query must be at least 2 characters' })
  }
  const posts = await postService.searchPosts(query)
  res.json({ data: posts })
})

router.get('/:id', async (req: Request, res: Response) => {
  const post = await postService.findById(parseInt(req.params.id))
  if (!post) return res.status(404).json({ error: 'Post not found' })

  postService.incrementViewCount(post.id)

  res.json({ data: post })
})

router.post('/', validateBody(['title', 'content']), async (req: Request, res: Response) => {
  const post = await postService.create(req.user!.id, req.body)
  res.status(201).json({ data: post })
})

router.put('/:id', async (req: Request, res: Response) => {
  const post = await postService.update(parseInt(req.params.id), req.body)
  res.json({ data: post })
})

router.delete('/:id', async (req: Request, res: Response) => {
  await postService.delete(parseInt(req.params.id))
  res.status(204).send()
})

// Nested comments
router.get('/:id/comments', async (req: Request, res: Response) => {
  const tree = req.query.tree === 'true'
  if (tree) {
    const comments = await commentService.getTreeByPost(parseInt(req.params.id))
    res.json({ data: comments })
  } else {
    const comments = await commentService.getByPost(parseInt(req.params.id))
    res.json({ data: comments })
  }
})

router.post('/:id/comments', validateBody(['content']), async (req: Request, res: Response) => {
  const comment = await commentService.create(req.user!.id, {
    post_id: parseInt(req.params.id),
    content: req.body.content,
    parent_id: req.body.parent_id,
  })
  res.status(201).json({ data: comment })
})

export default router
