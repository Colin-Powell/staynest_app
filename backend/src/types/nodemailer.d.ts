declare module 'nodemailer' {
  export interface Transporter {
    sendMail(options: any): Promise<any>;
  }

  export interface SendMailOptions {
    from?: string;
    to: string | string[];
    subject: string;
    text?: string;
    html?: string;
  }

  export function createTransport(config: any): Transporter;
}
