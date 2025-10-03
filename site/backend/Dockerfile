FROM node:20-alpine

RUN apk add --no-cache curl

RUN addgroup -g 1001 app && adduser -D -u 1001 -G app app

WORKDIR /app

COPY package.json ./

RUN npm install --omit=dev

COPY server.js ./

USER app

EXPOSE 3000
CMD ["node", "server.js"]
