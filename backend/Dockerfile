FROM node:20-alpine
WORKDIR /usr/src/app
COPY package.json package-lock.json* ./
RUN npm ci --include=dev
COPY . .
RUN npm run build
RUN npm prune --omit=dev
EXPOSE 8080
CMD ["sh", "-c", "npm run migrate && node dist/index.js"]
