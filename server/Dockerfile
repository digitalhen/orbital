FROM node:22-alpine
WORKDIR /app
COPY package.json .
COPY server.js .
COPY missions/ missions/
EXPOSE 3847
CMD ["node", "server.js"]
