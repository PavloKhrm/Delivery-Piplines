import { Module, OnModuleInit } from '@nestjs/common';

import { getRepositoryProviders } from '../../providers/database/repositories.provider';

import { BlogPostController } from './blog-post.controller';
import { BlogPostService } from './blog-post.service';
import { BlogPost } from './entities/blog-post.entity';

@Module({
  imports: [],
  providers: [BlogPostService, ...getRepositoryProviders(BlogPost)],
  controllers: [BlogPostController],
})
export class BlogPostModule implements OnModuleInit {
  constructor(private readonly blogPostService: BlogPostService) {}

  async onModuleInit() {
    await this.blogPostService.ensureIndex();
  }
}
