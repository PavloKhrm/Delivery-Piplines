import fastifyCors from '@fastify/cors';
import fastifySecureSession from '@fastify/secure-session';
import { NestFactory } from '@nestjs/core';
import {
  FastifyAdapter,
  NestFastifyApplication,
} from '@nestjs/platform-fastify';
import * as dotenv from 'dotenv';

import { AppModule } from './app.module';

// preload environment variables
dotenv.config();

export let app: NestFastifyApplication;

async function bootstrap() {
  app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter(),
  );

  await app.register(fastifySecureSession, {
    key: Buffer.from(process.env.SESSION_SECRET).subarray(0, 32), // Ensure exactly 32 bytes
    salt: Buffer.from(process.env.SESSION_SECRET).subarray(0, 32),
    cookieName: 'blog-session',
    cookie: {
      domain: process.env.APP_FRONTEND_DOMAIN || 'localhost',
      path: '/',
      secure: process.env.APP_ENV === 'production',
      httpOnly: true,
      sameSite: 'lax',
    },
    expiry: 24 * 60 * 60, // 1 day
  });

  await app.register(fastifyCors, {
    origin: true, // Allow all origins for local development
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    credentials: true,
    allowedHeaders:
      'Origin,Accept,Content-Type,Content-Length,Content-Range,Range,Authorization,X-CSRF-TOKEN',
  });

  await app.listen(
    process.env.APP_PORT ?? 3000,
    process.env.APP_HOST ?? '0.0.0.0',
  );
}

/**
 * Callback function to do stuff before app has closed
 *
 * @param {string} signal The signal that was received
 */
async function closeGracefully(signal: string) {
  console.log(`(｡･ω･)ﾉﾞ bye bye~ (${signal})\n`);

  await app.close();

  process.exit();
}

process.on('SIGINT', closeGracefully);
process.on('SIGTERM', closeGracefully);

bootstrap();
