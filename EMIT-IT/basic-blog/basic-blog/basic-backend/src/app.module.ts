import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';

import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './authentication/auth.module';
import { SessionAuthGuard } from './authentication/guards/session-auth.guard';
import { CustomCacheInterceptor } from './common/interceptors/cache-custom.interceptor';
import { BlogPostModule } from './models/blog-post/blog-post.module';
import { MysqlDatabaseProviderModule } from './providers/database/provider.module';
import { ElasticSearchProviderModule } from './providers/elasticsearch/elasticsearch-provider.module';
import { MailProviderModule } from './providers/mail/provider.module';
import { RedisProviderModule } from './providers/redis/provider.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    AuthModule,
    BlogPostModule,
    MysqlDatabaseProviderModule,
    ElasticSearchProviderModule,
    RedisProviderModule,
    MailProviderModule,
  ],
  controllers: [AppController],
  providers: [
    AppService,
    {
      provide: APP_GUARD,
      useClass: SessionAuthGuard,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: CustomCacheInterceptor,
    },
  ],
})
export class AppModule {}
