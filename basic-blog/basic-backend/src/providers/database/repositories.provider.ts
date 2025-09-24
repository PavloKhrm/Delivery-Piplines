import { DataSource } from 'typeorm';

export const MYSQL_DATA_SOURCE = 'MYSQL_DATA_SOURCE';

export function getRepositoryProviders(...entityClasses: any[]) {
  return entityClasses.map((entityClass) => ({
    provide: entityClass.name,
    useFactory: (dataSource: DataSource) =>
      dataSource.getRepository(entityClass),
    inject: [MYSQL_DATA_SOURCE],
  }));
}
