import { Body, Controller, Delete, Post, Req } from '@nestjs/common';
import { FastifyRequest } from 'fastify';

import { AuthService } from '@/authentication/auth.service';

import { RequireAuth } from './decorator/require-auth.decorator';
import { SignInDto } from './dto/signin.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('signin')
  async signIn(@Body() body: SignInDto, @Req() request: FastifyRequest) {
    return this.authService.signIn(body, request);
  }

  @Delete('signout')
  @RequireAuth()
  async signOut(@Req() request: FastifyRequest) {
    return this.authService.signOut(request);
  }
}
