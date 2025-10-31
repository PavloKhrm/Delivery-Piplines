export const DEF_API = process.env.DEFAULT_API_IMAGE || "index.docker.io/pavlokharaman/client-api:latest";
export const DEF_WEB = process.env.DEFAULT_WEB_IMAGE || "index.docker.io/pavlokharaman/client-web:latest";
export const DEF_API_PORT = Number(process.env.DEFAULT_API_PORT || 3000);
export const DEF_WEB_PORT = Number(process.env.DEFAULT_WEB_PORT || 80);
