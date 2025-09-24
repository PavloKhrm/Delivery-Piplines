import { Global, Module } from '@nestjs/common';
import { MailerModule } from '@nestjs-modules/mailer';

@Global()
@Module({
  imports: [
    MailerModule.forRootAsync({
      useFactory: () => {
        return {
          transport: {
            host: process.env.MAIL_HOST,
            port: process.env.MAIL_PORT,
            auth: null, // In order to simplify SMTP, there is no auth for this example project
          },
          defaults: {
            from: process.env.MAIL_DEFAULT_FROM,
          },
        };
      },
    }),
  ],
  exports: [MailerModule],
})
export class MailProviderModule {}
