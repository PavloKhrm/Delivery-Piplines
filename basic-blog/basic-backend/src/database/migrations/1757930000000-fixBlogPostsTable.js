/**
 * @typedef {import('typeorm').MigrationInterface} MigrationInterface
 */

/**
 * @class
 * @implements {MigrationInterface}
 */
module.exports = class FixBlogPostsTable1757930000000 {
    name = 'FixBlogPostsTable1757930000000'

    async up(queryRunner) {
        // Create correct table if it doesn't exist
        await queryRunner.query(
            'CREATE TABLE IF NOT EXISTS `blog_posts` (\`id\` int NOT NULL AUTO_INCREMENT, \`title\` varchar(255) NOT NULL, \`content\` varchar(5000) NOT NULL, \`created_at\` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, \`updated_at\` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, PRIMARY KEY (\`id\`)) ENGINE=InnoDB'
        );

        // If an old table exists with wrong name, optionally migrate data then drop it
        await queryRunner.query(
            'DROP TABLE IF EXISTS `blog_post`'
        );
    }

    async down(queryRunner) {
        // Recreate old table on revert (empty)
        await queryRunner.query(
            'CREATE TABLE IF NOT EXISTS `blog_post` (\`id\` int NOT NULL AUTO_INCREMENT, \`title\` varchar(255) NOT NULL, \`content\` varchar(5000) NOT NULL, \`created_at\` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP, \`updated_at\` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, PRIMARY KEY (\`id\`)) ENGINE=InnoDB'
        );
        await queryRunner.query('DROP TABLE IF EXISTS `blog_posts`');
    }
}



