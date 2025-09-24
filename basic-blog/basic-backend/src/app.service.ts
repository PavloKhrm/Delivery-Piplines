import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getAppInfo() {
    return {
      name: process.env.APP_NAME,
      contact_mail: process.env.APP_CONTACT_MAIL,
      contact_website: process.env.APP_CONTACT_WEBSITE,
      tz: process.env.APP_TIMEZONE,
    };
  }
}
