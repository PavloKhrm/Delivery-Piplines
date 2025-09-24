import {
  createParamDecorator,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';

/**
 * Custom decorator to require a valid session using fastify/secure-session.
 * Throws UnauthorizedException if session is missing or invalid.
 */
export const AuthenticatedUser = createParamDecorator(
  (data: unknown, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();

    // Fastify stores session on request.session
    if (!request.session || !request.session.get('user')) {
      throw new UnauthorizedException('Session is invalid or missing');
    }

    // Optionally, return userId or session object
    return request.session.get('user');
  },
);
