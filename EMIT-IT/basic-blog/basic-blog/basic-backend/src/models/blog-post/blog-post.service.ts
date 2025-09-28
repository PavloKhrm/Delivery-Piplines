import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Inject, Injectable } from '@nestjs/common';
import { NotFoundException } from '@nestjs/common';
import { ElasticsearchService } from '@nestjs/elasticsearch';
import { Cache } from 'cache-manager';
import { Repository } from 'typeorm';

import { BlogPost } from './entities/blog-post.entity';
import {
  BLOG_POST_INDEX,
  blogPostIndexMapping,
  transformEntityToIndex,
} from './index/blog-post.index';

export interface CustomPaginateMeta {
  totalItems: number;
  itemsPerPage: number;
  totalPages: number;
  currentPage: number;
}

export interface CustomPaginated<T> {
  data: T[];
  meta: CustomPaginateMeta;
}

@Injectable()
export class BlogPostService {
  constructor(
    @Inject(BlogPost.name)
    private readonly blogPostRepository: Repository<BlogPost>,
    private readonly elasticsearchService: ElasticsearchService,
    @Inject(CACHE_MANAGER)
    private cacheManager: Cache,
  ) {}

  async ensureIndex() {
    const exists = await this.elasticsearchService.indices.exists({
      index: BLOG_POST_INDEX,
    });

    if (!exists) {
      await this.elasticsearchService.indices.create({
        index: BLOG_POST_INDEX,
        ...blogPostIndexMapping,
      });

      // index all blog posts
      const allPosts = await this.blogPostRepository.find();
      for (const post of allPosts) {
        await this.elasticsearchService.index({
          index: BLOG_POST_INDEX,
          id: post.id.toString(),
          document: transformEntityToIndex(post),
        });
      }
    }
  }

  async reindexAll() {
    await this.elasticsearchService.indices.delete(
      { index: BLOG_POST_INDEX },
      { ignore: [404] },
    );
    await this.ensureIndex();
  }

  async findAll(
    page = 1,
    limit = 10,
    query?: string,
  ): Promise<CustomPaginated<BlogPost>> {
    const result = await this.elasticsearchService.search<BlogPost>({
      index: BLOG_POST_INDEX,
      query: query
        ? {
            multi_match: {
              query,
              fields: ['title', 'content'],
            },
          }
        : undefined,
      from: (page - 1) * limit,
      size: limit,
      sort: [{ createdAt: 'desc' }],
    });
    const items = result.hits.hits.map((hit: any) => hit._source);
    const totalHits =
      typeof result.hits.total === 'number'
        ? result.hits.total
        : result.hits.total?.value || 0;

    return {
      data: items,
      meta: {
        totalItems: totalHits,
        itemsPerPage: limit,
        totalPages: Math.ceil(totalHits / limit),
        currentPage: page,
      },
    };
  }

  async findOne(id: number) {
    const post = await this.blogPostRepository.findOne({ where: { id } });

    if (!post) {
      throw new NotFoundException(`BlogPost with id ${id} not found`);
    }

    return post;
  }

  async create(createBlogPostDto: any) {
    const newPost = this.blogPostRepository.create(createBlogPostDto);
    await this.blogPostRepository.save(newPost);

    // Force indexation: HACKY but works whatever
    const newItem = await this.blogPostRepository.findOne({
      where: {
        title: createBlogPostDto.title,
        content: createBlogPostDto.content,
      },
      order: { id: 'DESC' },
    });
    await this.elasticsearchService.index({
      index: BLOG_POST_INDEX,
      id: newItem.id.toString(),
      document: transformEntityToIndex(newItem),
    });
    await new Promise((resolve) => setTimeout(resolve, 500));

    return newItem;
  }

  async update(id: number, updateBlogPostDto: any) {
    const post = await this.blogPostRepository.findOne({ where: { id } });

    if (!post) {
      throw new NotFoundException(`BlogPost with id ${id} not found`);
    }
    await this.blogPostRepository.update(id, updateBlogPostDto);
    const updated = await this.blogPostRepository.findOne({ where: { id } });

    if (updated) {
      await this.elasticsearchService.index({
        index: BLOG_POST_INDEX,
        id: updated.id.toString(),
        document: transformEntityToIndex(updated),
      });
    }

    // remove the cache item for findOne
    this.cacheManager.del(`/blog-post/${id}`);

    return updated;
  }

  async remove(id: number) {
    const post = await this.blogPostRepository.findOne({ where: { id } });

    if (!post) {
      throw new NotFoundException(`BlogPost with id ${id} not found`);
    }
    await this.elasticsearchService.delete({
      index: BLOG_POST_INDEX,
      id: id.toString(),
    });

    return this.blogPostRepository.delete(id);
  }
}
