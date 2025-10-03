FROM node:20-alpine

# create non-root user
RUN addgroup -g 1001 app && adduser -D -u 1001 -G app app

WORKDIR /app

# install prod deps first (better layer cache)
COPY package.json ./
RUN npm i --only=production

# copy source
COPY server.js ./

# drop privileges
USER app

EXPOSE 3000
CMD ["npm", "start"]
