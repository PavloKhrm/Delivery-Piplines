import { Injectable, Req, UnauthorizedException } from '@nestjs/common';
import { MailerService } from '@nestjs-modules/mailer';
import { FastifyRequest } from 'fastify';

import { users } from '@/authentication/common';

import { SignInDto } from './dto/signin.dto';

@Injectable()
export class AuthService {
  constructor(private readonly mailerService: MailerService) {}

  /**
   * Validates the user's authentication details.
   * @param username
   * @param pass
   * @returns User object without password if valid, otherwise throws UnauthorizedException.
   */
  async signIn(signInDto: SignInDto, request: FastifyRequest) {
    // === IMPORTANT NOTE ===
    // Usually, you must use password hashing algorithms and verify those hashes (e.g. with bcrypt or Argon2),
    // so user matching below is DEFINITELY not the way how one would implement user authentication 🫠
    const user = users.find(
      (user) =>
        user.username === signInDto.username &&
        user.password === signInDto.password,
    );

    // When implementing a proper user service, replace the following line with a call to that service.
    // Also make sure to hash and salt passwords in a real application.
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { password, ...result } = user;

    // Create a new fastify secure session
    // @ts-expect-error Fastify session typing is broken
    request.session.set('user', user);

    this.mailerService
      .sendMail({
        to: `${user.username}@blog.local`,
        subject: 'New login',
        html: `<p>Hi ${user.username}!</p><p>There was a new login from <strong>${request.ip}</strong>.</p>`,
      })
      .then(() => undefined)
      .catch(() => undefined);

    return result;
  }

  /**
   * Signs out the user by deleting their session.
   * @param request Fastify request, used to access and delete the session.
   */
  async signOut(@Req() request: FastifyRequest) {
    request.session.delete();

    return 'Successfully logged out';
  }
}
