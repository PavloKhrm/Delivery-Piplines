import KeyvRedis from '@keyv/redis';
import { CacheModule } from '@nestjs/cache-manager';
import { Global, Module } from '@nestjs/common';

@Global()
@Module({
  imports: [
    CacheModule.registerAsync({
      useFactory: async () => {
        return {
          stores: [
            new KeyvRedis(
              `redis://default:${encodeURIComponent(process.env.REDIS_PASSWORD)}@${process.env.REDIS_HOST}:6379`,
            ),
          ],
          ttl: parseInt(process.env.REDIS_CACHE_TTL) || 300000,
        };
      },
    }),
  ],
  exports: [CacheModule],
})
export class RedisProviderModule {}
