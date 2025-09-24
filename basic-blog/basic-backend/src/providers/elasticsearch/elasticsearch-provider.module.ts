import { Global, Module } from '@nestjs/common';
import { ElasticsearchModule } from '@nestjs/elasticsearch';

@Global()
@Module({
  imports: [
    ElasticsearchModule.registerAsync({
      useFactory: () => {
        return {
          node: process.env.ELASTIC_NODE_ENDPOINT || 'http://localhost:9200',
          auth: {
            username: 'elastic',
            password: process.env.ELASTIC_PASSWORD || 'changeme',
          },
        };
      },
    }),
  ],
  exports: [ElasticsearchModule],
})
export class ElasticSearchProviderModule {}
