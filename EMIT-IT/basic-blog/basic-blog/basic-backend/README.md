# Simple blog back-end setup

- Make sure you have the correct version of Node (version 22.xx.x LTS) and NPM
- Copy `.env.example` to `.env` and fill in environment vars (if there is no `.env` file yet)
- Install node_modules: `npm i`
- Start docker containers: `docker compose up`
- Build: `npm run build`
- Migrate database schema: `npm run migration`
- Seed data: `npm run seed`
- Start backend dev server: `npm run dev`
