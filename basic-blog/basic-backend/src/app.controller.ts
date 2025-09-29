import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Controller, Get, Inject } from '@nestjs/common';

import { AppService } from './app.service';
import { RequireAuth } from './authentication/decorator/require-auth.decorator';

import type { Cache } from 'cache-manager';

@Controller()
export class AppController {
  constructor(
    private readonly appService: AppService,
    @Inject(CACHE_MANAGER) private cacheManager: Cache,
  ) {}

  @Get()
  @RequireAuth()
  getAppInfo() {
    return this.appService.getAppInfo();
  }

  @Get('health')
  getHealth() {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }
}
