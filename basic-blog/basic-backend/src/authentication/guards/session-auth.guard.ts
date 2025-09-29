import {
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';
import { FastifyRequest } from 'fastify';

import { REQUIRE_AUTH_KEY } from '../decorator/require-auth.decorator';
import User from '../types/user';

@Injectable()
export class SessionAuthGuard extends AuthGuard('session') {
  constructor(private reflector: Reflector) {
    super();
  }

  canActivate(context: ExecutionContext) {
    if (this.canSkip(context)) {
      return true;
    }

    const ctx = context.switchToHttp();
    const req = ctx.getRequest() as FastifyRequest;

    const session = req.session.get('user') as Omit<User, 'password'>;

    // No session cookie was found or session cookie has no sessionId, so deny access.
    // This is done before session strategy, because of the huge injection scope in session strategy.
    // It is more performant to instantly block access when a session cookie or session ID is not available.
    if (!session) {
      throw new UnauthorizedException('Session is invalid or missing');
    }

    return super.canActivate(context);
  }

  /** Whether it is possible to skip the session check */
  private canSkip(context: ExecutionContext) {
    const isAuthenticated = this.reflector.getAllAndOverride<boolean>(
      REQUIRE_AUTH_KEY,
      [context.getHandler(), context.getClass()],
    );

    // Route or controller is decorated with RequireAuth, so allow access
    return !isAuthenticated;
  }
}
