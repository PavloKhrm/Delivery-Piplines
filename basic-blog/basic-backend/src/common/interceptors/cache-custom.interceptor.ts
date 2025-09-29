import { CacheInterceptor } from '@nestjs/cache-manager';
import { Injectable, ExecutionContext } from '@nestjs/common';
import { startsWith } from 'lodash';

@Injectable()
export class CustomCacheInterceptor extends CacheInterceptor {
  excludePaths = ['/blog-post?'];
  protected allowedMethods: string[] = ['GET'];

  isRequestCacheable(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest();

    return (
      this.allowedMethods.includes(req.method) &&
      !startsWith(req.url, this.excludePaths[0])
    );
  }
}
