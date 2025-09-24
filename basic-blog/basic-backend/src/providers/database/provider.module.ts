import { Global, Module } from '@nestjs/common';

import dataSource from './datasource';
import { MYSQL_DATA_SOURCE } from './repositories.provider';

export const databaseProviders = [
  {
    provide: MYSQL_DATA_SOURCE,
    useFactory: () => dataSource.initialize(),
  },
];

@Global()
@Module({
  providers: [...databaseProviders],
  exports: [...databaseProviders],
})
export class MysqlDatabaseProviderModule {}
