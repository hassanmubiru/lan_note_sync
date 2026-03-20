FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY server.js .
EXPOSE 3031
ENV PORT=3031
ENV CORS_ORIGIN=*
CMD ["node", "server.js"]
