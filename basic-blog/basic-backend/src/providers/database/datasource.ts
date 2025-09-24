/* eslint-disable @typescript-eslint/no-var-requires */
import { DataSource, DataSourceOptions } from 'typeorm';
import { SnakeNamingStrategy } from 'typeorm-naming-strategies';

require('dotenv').config();

const { env } = process;

export const mySqlDataSourceOptions: DataSourceOptions = {
  type: 'mysql',
  host: env.DATABASE_HOST,
  port: 3306,
  username: env.DATABASE_USERNAME,
  password: env.DATABASE_PASSWORD,
  database: env.DATABASE_NAME,
  bigNumberStrings: false,
  supportBigNumbers: true,
  entities: ['./dist/**/*.entity.js'],
  migrations: ['./src/database/migrations/*.js'],
  namingStrategy: new SnakeNamingStrategy(),
  synchronize: false, // Don't set to `true`! Auto syncing entities is a broken feature within TypeORM and will mess up your schema. Please, only work with migrations.
  legacySpatialSupport: false,
};

const mySqlDataSource = new DataSource(mySqlDataSourceOptions);

export default mySqlDataSource;
