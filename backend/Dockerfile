FROM node:20-alpine
WORKDIR /usr/src/app
COPY package.json package-lock.json* ./
RUN npm install --production
COPY . .
RUN npm run build
EXPOSE 8080
CMD ["sh", "-c", "npm run migrate && node dist/index.js"]
