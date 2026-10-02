# syntax=docker/dockerfile:1

# ---- deps: instala somente dependências de produção ----
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev

# ---- ca: bundle de certificados da RDS (validação TLS) ----
FROM alpine:3.20 AS ca
RUN wget -q -O /rds-global-bundle.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# ---- runtime: imagem final mínima, usuário não-root ----
FROM node:20-alpine
ENV NODE_ENV=production \
    API_PORT=3000
WORKDIR /app

COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node package.json ./
COPY --chown=node:node src ./src
COPY --from=ca --chown=node:node /rds-global-bundle.pem ./certs/rds-global-bundle.pem

USER node
EXPOSE 3000

# GET / não depende do banco, então serve como liveness
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${API_PORT}/" >/dev/null || exit 1

CMD ["node", "src/index.js"]
