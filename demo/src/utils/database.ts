export interface QueryOptions {
  offset?: number
  limit?: number
  orderBy?: string
}

export const db = {
  async findOne(table: string, filter: Record<string, any>): Promise<any> {
    return null
  },

  async findMany(table: string, filter: Record<string, any>, options?: QueryOptions): Promise<any[]> {
    return []
  },

  async insert(table: string, data: Record<string, any>): Promise<any> {
    return { id: 1, ...data }
  },

  async update(table: string, filter: Record<string, any>, data: Record<string, any>): Promise<any> {
    return data
  },

  async updateMany(table: string, filter: Record<string, any>, data: Record<string, any>): Promise<{ affected: number }> {
    return { affected: 0 }
  },

  async delete(table: string, filter: Record<string, any>): Promise<void> {},

  async deleteMany(table: string, filter: Record<string, any>): Promise<{ affected: number }> {
    return { affected: 0 }
  },

  async count(table: string, filter: Record<string, any>): Promise<number> {
    return 0
  },

  async search(table: string, fields: string[], query: string): Promise<any[]> {
    return []
  },

  async query(sql: string): Promise<any> {
    return null
  },
}
