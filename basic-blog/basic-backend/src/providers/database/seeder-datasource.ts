import { DataSource, DataSourceOptions } from 'typeorm';

import { mySqlDataSourceOptions } from './datasource';

const mySqlDataSourceForSeeder = new DataSource({
  ...mySqlDataSourceOptions,
  synchronize: false,
  migrationsRun: false,
} as DataSourceOptions);

export default mySqlDataSourceForSeeder;
