FROM node:22 AS builder
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci

COPY quartz.lock.json quartz.config.yaml quartz.ts ./
COPY globals.d.ts index.d.ts tsconfig.json ./
COPY quartz/ ./quartz/
COPY plugins/ ./plugins/
COPY content/ ./content/

RUN npx quartz plugin install --from-config && npx quartz build

FROM node:22-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production

RUN echo '{"type":"module","dependencies":{"serve-handler":"^6.1.6"}}' > package.json \
 && npm install --omit=dev --no-audit --no-fund \
 && rm -f package-lock.json

COPY --from=builder /app/public ./public
COPY server.mjs ./

EXPOSE 8080
CMD ["node", "server.mjs"]
