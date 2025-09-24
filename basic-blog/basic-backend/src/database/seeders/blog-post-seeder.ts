import { Seeder } from '@concepta/typeorm-seeding';
import { faker } from '@faker-js/faker';

import mySqlDataSource from '@/providers/database/datasource';

import { BlogPost } from '../../models/blog-post/entities/blog-post.entity';

/**
 * A seeder for blog post test data
 */
export class BlogPostSeeder extends Seeder {
  async run() {
    const datasource = await mySqlDataSource.initialize();
    const blogPostRepository = datasource.getRepository(BlogPost);

    // Create a bunch of blog posts
    for (let i = 0; i < 100; i++) {
      const post = new BlogPost();
      post.title = faker.hacker.phrase();
      post.content =
        faker.hacker.phrase() + '\n\n' + faker.lorem.paragraphs(5, '\n\n');
      await blogPostRepository.save(post);
    }
  }
}
