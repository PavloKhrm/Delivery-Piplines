import { exec } from 'child_process';
import { kebabCase } from 'lodash';

(async () => {
  try {
    await new Promise((resolve, reject) => {
      const args = process.argv.slice(2);

      if (args.length === 0) {
        throw new Error(
          'No argument was passed for the name of the migration. Please, try again',
        );
      }

      const migrationName = kebabCase(args.join(' ').toLowerCase());
      const migrate = exec(
        `npx typeorm migration:generate ./src/database/migrations/${migrationName} -d ./dist/providers/database/datasource.js -o`,
        { env: process.env },
        (err) => (err ? reject(err) : resolve(true)),
      );

      // Forward stdout+stderr to this process
      migrate.stdout.pipe(process.stdout);
      migrate.stderr.pipe(process.stderr);
    });
  } catch (e) {
    console.error('Migration operation has failed');
    console.error(e);
  }
})();
