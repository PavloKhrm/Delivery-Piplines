import { Global, Module } from '@nestjs/common';
import { ElasticsearchModule } from '@nestjs/elasticsearch';

@Global()
@Module({
  imports: [
    ElasticsearchModule.registerAsync({
      useFactory: () => {
        const elasticsearchHost = process.env.ELASTICSEARCH_HOST || 'localhost';
        const elasticsearchPort = process.env.ELASTICSEARCH_PORT || '9200';
        const nodeUrl = `http://${elasticsearchHost}:${elasticsearchPort}`;
        
        return {
          node: nodeUrl,
          auth: {
            username: process.env.ELASTICSEARCH_USERNAME || 'elastic',
            password: process.env.ELASTIC_PASSWORD || 'changeme',
          },
        };
      },
    }),
  ],
  exports: [ElasticsearchModule],
})
export class ElasticSearchProviderModule {}
