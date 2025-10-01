/**
 * @typedef {import('typeorm').MigrationInterface} MigrationInterface
 */

/**
 * @class
 * @implements {MigrationInterface}
 */
module.exports = class RenameBlogPostsColumns1757930100000 {
    name = 'RenameBlogPostsColumns1757930100000'

    async up(queryRunner) {
        // Rename snake_case to camelCase to match entity fields
        await queryRunner.query('ALTER TABLE `blog_posts` CHANGE `created_at` `createdAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP');
        await queryRunner.query('ALTER TABLE `blog_posts` CHANGE `updated_at` `updatedAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');
    }

    async down(queryRunner) {
        // Revert back to snake_case
        await queryRunner.query('ALTER TABLE `blog_posts` CHANGE `updatedAt` `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');
        await queryRunner.query('ALTER TABLE `blog_posts` CHANGE `createdAt` `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP');
    }
}



