import { SeedingSource } from '@concepta/typeorm-seeding';

import dataSource from '@/providers/database/seeder-datasource';

import { BlogPostSeeder } from './blog-post-seeder';

export default new SeedingSource({
  dataSource,
  seeders: [BlogPostSeeder],
});
